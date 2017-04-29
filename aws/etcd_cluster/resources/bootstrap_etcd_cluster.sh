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

echo " ((((())))) 0o0o >>> Sleeping for 30 seconds (the time to be sure that our cloud config has been applied)"
sleep 30s

# TODO FIXME(etienne): reduce code duplication below
# Stopping etcd on all nodes
for ip in "${ip_addresses[@]}"; do
  echo " ((((())))) 0o0o >>> Stopping etcd on node $ip"
  ssh -i "$PRIVATE_SSH_KEY_PATH" -oStrictHostKeyChecking=no -oProxyCommand="ssh -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -oStrictHostKeyChecking=no -q -W %h:%p terraform@$BASTION_IP" "terraform@$ip" sudo systemctl stop etcd-member.service
done

# Copying bootstrap configuration on all nodes
for ip in "${ip_addresses[@]}"; do
  echo " ((((())))) 0o0o >>> Copying bootstraping configuration to node $ip, reloading systemd config and cleaning up etcd data dir"
  cat <<EOF  > "$MODULE_PATH/resources/100-etcd-bootstrap.conf"
[Service]
# Initial cluster configuration
Environment=ETCD_INITIAL_CLUSTER_STATE=new
Environment=ETCD_INITIAL_CLUSTER=$initial_cluster
EOF
  scp -i "$PRIVATE_SSH_KEY_PATH" -oStrictHostKeyChecking=no -oProxyCommand="ssh -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -oStrictHostKeyChecking=no -q -W %h:%p terraform@$BASTION_IP" "$MODULE_PATH/resources/100-etcd-bootstrap.conf" "terraform@${ip}:100-etcd-bootstrap.conf"
  ssh -i "$PRIVATE_SSH_KEY_PATH" -oStrictHostKeyChecking=no -oProxyCommand="ssh -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -oStrictHostKeyChecking=no -q -W %h:%p terraform@$BASTION_IP" "terraform@$ip" sudo mkdir -p /etc/systemd/system/etcd-member.service.d/
  ssh -i "$PRIVATE_SSH_KEY_PATH" -oStrictHostKeyChecking=no -oProxyCommand="ssh -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -oStrictHostKeyChecking=no -q -W %h:%p terraform@$BASTION_IP" "terraform@$ip" sudo mv /home/terraform/100-etcd-bootstrap.conf /etc/systemd/system/etcd-member.service.d/100-etcd-bootstrap.conf

  ssh -i "$PRIVATE_SSH_KEY_PATH" -oStrictHostKeyChecking=no -oProxyCommand="ssh -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -oStrictHostKeyChecking=no -q -W %h:%p terraform@$BASTION_IP" "terraform@$ip" sudo systemctl daemon-reload
  ssh -i "$PRIVATE_SSH_KEY_PATH" -oStrictHostKeyChecking=no -oProxyCommand="ssh -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -oStrictHostKeyChecking=no -q -W %h:%p terraform@$BASTION_IP" "terraform@$ip" sudo rm -rf /var/lib/etcd/*
done

# Starting etcd on all nodes
for ip in "${ip_addresses[@]}"; do
  echo " ((((())))) o0o0 >>> Starting etcd on node N $ip"
  ssh -i "$PRIVATE_SSH_KEY_PATH" -oStrictHostKeyChecking=no -oProxyCommand="ssh -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -oStrictHostKeyChecking=no -q -W %h:%p terraform@$BASTION_IP" "terraform@$ip" sudo systemctl start etcd-member.service &
done

# Wait for the 3 etcd nodes to form a cluster (cf. the systemd start commands
# ran above in the background)
echo "((((())))) o0o0 >>> Waiting for the 3 etcd nodes (${ip_addresses}) to start and form a cluster..."
wait
echo "((((())))) o0o0 >>> All three nodes should be ready now."

for ip in "${ip_addresses[@]}"; do
  echo " ((((())))) o0o0 >>> Removing bootstrap specific systemd drop-in on node $ip and make ELB health check succeed so that our cluster can be reached"
  ssh -i "$PRIVATE_SSH_KEY_PATH" -oStrictHostKeyChecking=no -oProxyCommand="ssh -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -oStrictHostKeyChecking=no -q -W %h:%p terraform@$BASTION_IP" "terraform@$ip" sudo rm -f /etc/systemd/system/etcd-member.service.d/100-etcd-bootstrap.conf
  ssh -i "$PRIVATE_SSH_KEY_PATH" -oStrictHostKeyChecking=no -oProxyCommand="ssh -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -oStrictHostKeyChecking=no -q -W %h:%p terraform@$BASTION_IP" "terraform@$ip" etcdctl set letsdreem true

  # Never forget to clean up behind you ;-)
  rm -f "$MODULE_PATH/resources/100-etcd-bootstrap.conf"
done

echo " ((((())))) [GREAT SUCCESS] ETCD BOOTSTRAP COMPLETE AND SUCCESSFUL, HAVE FUN ! "

exit 0
