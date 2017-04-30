#!/bin/bash

#
# Bootstrap an etcd cluster in an autoscaling group by fetching the IPs of all
# its members and setting them as ETCD_INITIAL_CLUSTER configuration.
# The script takes care of systemd module reloading, restarting etcd and even
# of deleting the bootstrapping config. so that the cluster can mutate on its
# own, without risk.
#
# Maintainer: Étienne Lafarge <etienne@rythm.co>
#

echo " ((((())))) Hello, this is Terraform speaking..."
echo " ((((())))) Let's Bootstrap our etcd cluster once and for all..."

REGION="$1"
PRIVATE_SSH_KEY_PATH="$2"
BASTION_IP="$3"
SSH_PORT="$4"
ASG_NAME="$5"
ASG_MIN_SIZE="$6"
MODULE_PATH="$7"
ETCD_ENDPOINT="$8"
ETCD_HEALTH_KEY="$9"

echo " ((((())))) Let me wait for the auto-scaling group instances to be up and running..."
instance_ids_json=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --region "$REGION" \
    --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId' \
    --no-paginate)
instance_ids=($(sed 's/,/ /g' <<< "$(sed 's/[][ "]//g' <<< "$(tr '\n' ' ' <<< "$instance_ids_json")")"))

while [[ "${#instance_ids}" -le $ASG_MIN_SIZE ]]; do
  sleep 5s
  instance_ids_json=$(aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names "$ASG_NAME" \
      --region "$REGION" \
      --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId' \
      --no-paginate)
  instance_ids=($(sed 's/,/ /g' <<< "$(sed 's/[][ "]//g' <<< "$(tr '\n' ' ' <<< "$instance_ids_json")")"))
done

ip_addresses=$(aws ec2 describe-instances \
    --region "$REGION" \
    --instance-ids "${instance_ids[@]}" \
    --query 'Reservations[*].Instances[*].PrivateIpAddress')

ip_addresses=($(sed 's/,/ /g' <<< "$(sed 's/[][ "]//g' <<< "$(tr '\n' ' ' <<< "$ip_addresses")")"))

echo " ((((())))) All set, we have $ASG_MIN_SIZE etcd instances running on ${ip_addresses[*]} let's bootstrap our cluster (using bastion $BASTION_IP to connect to it)..."

initial_cluster=""
for ip in "${ip_addresses[@]}"; do
  initial_cluster="${initial_cluster},etcd_${ip}=http://${ip}:2380"
done
initial_cluster=$(sed 's/^.//' <<< "$initial_cluster")

# Building SSH command prefix (with bastion proxying)
proxy_ssh_cmd="ssh  -o 'StrictHostKeyChecking=no' -o 'ConnectTimeout=5' -o 'BatchMode=yes' -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -q -l terraform -W '[%h]:%p' $BASTION_IP"
bastion_ssh_cmd=(ssh -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -o "StrictHostKeyChecking=no" -o "ConnectTimeout=5" -o "BatchMode=yes" -q "terraform@$BASTION_IP")
etcd_ssh_cmd=(ssh -o "StrictHostKeyChecking=no" -o "ConnectTimeout=5" -o "BatchMode=yes" -o "ProxyCommand $proxy_ssh_cmd")

# Stopping etcd on all nodes
echo " ((((())))) 0o0o >>> Waiting for the cloud config to be applied on all three etcd nodes and stop etcd-member systemd service..."
for ip in "${ip_addresses[@]}"; do
  echo " ((((())))) 0o0o >>> Stopping etcd on node $ip"
  while ! "${etcd_ssh_cmd[@]}" "terraform@$ip" sudo systemctl stop etcd-member.service; do
    echo " ((((())))) 0o0o >>> Node $ip isn't available over SSH yet, retrying in 5s..."
    sleep 5s
  done
done

# Copying bootstrap configuration on all nodes
echo " ((((())))) 0o0o >>> Building bootstraping configuration:"
read -r -d '' bootstrap_drop_in <<EOF
[Service]
# Initial cluster configuration
Environment=ETCD_INITIAL_CLUSTER_STATE=new
Environment=ETCD_INITIAL_CLUSTER=$initial_cluster
EOF
echo -e "$bootstrap_drop_in"

for ip in "${ip_addresses[@]}"; do
  echo " ((((())))) 0o0o >>> Copying bootstraping configuration from bastion to node $ip, reloading systemd config and cleaning up etcd data dir"

  "${etcd_ssh_cmd[@]}" "terraform@$ip" sudo mkdir -p /etc/systemd/system/etcd-member.service.d/
  "${etcd_ssh_cmd[@]}" "terraform@$ip" "sudo bash -c \"echo -e \\\"$bootstrap_drop_in\\\" > /etc/systemd/system/etcd-member.service.d/100-etcd-bootstrap.conf\""
  "${etcd_ssh_cmd[@]}" "terraform@$ip" sudo systemctl daemon-reload
  "${etcd_ssh_cmd[@]}" "terraform@$ip" sudo rm -rf /var/lib/etcd/*
done

# Starting etcd on all nodes
for ip in "${ip_addresses[@]}"; do
  echo " ((((())))) o0o0 >>> Starting etcd on node N $ip"
  "${etcd_ssh_cmd[@]}" "terraform@$ip" sudo systemctl start etcd-member.service &
done

# Wait for the 3 etcd nodes to form a cluster (cf. the systemd start commands
# ran above in the background)
echo " ((((())))) o0o0 >>> Waiting for the 3 etcd nodes (${ip_addresses[*]}) to start and form a cluster..."
wait
echo " ((((())))) o0o0 >>> All three nodes should be ready now."

for ip in "${ip_addresses[@]}"; do
  echo " ((((())))) o0o0 >>> Removing bootstrap specific systemd drop-in on node $ip"
  "${etcd_ssh_cmd[@]}" "terraform@$ip" sudo rm -f /etc/systemd/system/etcd-member.service.d/100-etcd-bootstrap.conf

  # Never forget to clean up behind you ;-)
  rm -f "$MODULE_PATH/resources/100-etcd-bootstrap.conf"
done

echo " ((((())))) o0o0 >>> Make ELB health check succeed (by adding the $ETCD_HEALTH_KEY key on one the first node) so that our cluster can be reached from anywhere in our VPC"
while ! "${etcd_ssh_cmd[@]}" "terraform@${ip_addresses[0]}" etcdctl set "$ETCD_HEALTH_KEY" true ; do
  echo " ((((())))) o0o0 >>> etcd node isn't ready yet. Retrying in 5 seconds..."
  sleep 5s
done

# Finally, let's wait for the cluster to be reachable from the bastion host.
# This is a way to make sure that DNS routes have propagated to the cluster and
# that the cluster has been formed sucessfully.
consecutively_successful_checks=0
while [[ "$consecutively_successful_checks" -le 10 ]]; do
  "${bastion_ssh_cmd[@]}" etcdctl --endpoints="$ETCD_ENDPOINT" get "$ETCD_HEALTH_KEY"
  status="$?"
  if [[ "$status" -eq 0 ]]; then
    consecutively_successful_checks=$((consecutively_successful_checks+1))
  else
    echo " ((((())))) o0o0 >>> Failed to reach etcd cluster, retrying in 5s..."
    consecutively_successful_checks=0
    sleep 5s
  fi
done

echo " ((((())))) o0o0 >>> [INFO] Printing etcdctl cluster-health output:"
"${bastion_ssh_cmd[@]}" etcdctl --endpoints="$ETCD_ENDPOINT" cluster-health

echo " ((((())))) [GREAT SUCCESS] ETCD BOOTSTRAP COMPLETE AND SUCCESSFUL, HAVE FUN ! "

exit 0
