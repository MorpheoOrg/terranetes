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

# TODO FIXME eeerk: let's rather get the status from the EC2 API to make sure the instances are ready for SSH
sleep 100s

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

for ip in "${ip_addresses[@]}"; do
  echo " ((((())))) 0o0o >>> Copying bootstrapping configuration to node $ip"
  cat <<EOF  > "$MODULE_PATH/resources/100-etcd-bootstrap.conf"
[Service]
# Initial cluster configuration
Environment=ETCD_INITIAL_CLUSTER_STATE=new
Environment=ETCD_INITIAL_CLUSTER=$initial_cluster
EOF
  scp -i "$PRIVATE_SSH_KEY_PATH" -oStrictHostKeyChecking=no -oProxyCommand="ssh -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -oStrictHostKeyChecking=no -q -W %h:%p terraform@$BASTION_IP" "$MODULE_PATH/resources/100-etcd-bootstrap.conf" "terraform@${ip}:100-etcd-bootstrap.conf"
  ssh -i "$PRIVATE_SSH_KEY_PATH" -oStrictHostKeyChecking=no -oProxyCommand="ssh -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -oStrictHostKeyChecking=no -q -W %h:%p terraform@$BASTION_IP" "terraform@$ip" sudo mkdir -p /etc/systemd/system/etcd-member.service.d/
  ssh -i "$PRIVATE_SSH_KEY_PATH" -oStrictHostKeyChecking=no -oProxyCommand="ssh -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -oStrictHostKeyChecking=no -q -W %h:%p terraform@$BASTION_IP" "terraform@$ip" sudo systemctl stop etcd-member.service
  ssh -i "$PRIVATE_SSH_KEY_PATH" -oStrictHostKeyChecking=no -oProxyCommand="ssh -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -oStrictHostKeyChecking=no -q -W %h:%p terraform@$BASTION_IP" "terraform@$ip" sudo mv /home/terraform/100-etcd-bootstrap.conf /etc/systemd/system/etcd-member.service.d/100-etcd-bootstrap.conf

  echo " ((((())))) o0o0 >>> Starting etcd on node N $ip"
  ssh -i "$PRIVATE_SSH_KEY_PATH" -oStrictHostKeyChecking=no -oProxyCommand="ssh -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -oStrictHostKeyChecking=no -q -W %h:%p terraform@$BASTION_IP" "terraform@$ip" sudo systemctl daemon-reload
  ssh -i "$PRIVATE_SSH_KEY_PATH" -oStrictHostKeyChecking=no -oProxyCommand="ssh -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -oStrictHostKeyChecking=no -q -W %h:%p terraform@$BASTION_IP" "terraform@$ip" sudo rm -rf /var/lib/etcd/*
  ssh -i "$PRIVATE_SSH_KEY_PATH" -oStrictHostKeyChecking=no -oProxyCommand="ssh -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -oStrictHostKeyChecking=no -q -W %h:%p terraform@$BASTION_IP" "terraform@$ip" sudo systemctl start etcd-member.service &
  ssh -i "$PRIVATE_SSH_KEY_PATH" -oStrictHostKeyChecking=no -oProxyCommand="ssh -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -oStrictHostKeyChecking=no -q -W %h:%p terraform@$BASTION_IP" "terraform@$ip" sudo rm -f /etc/systemd/system/etcd-member.service.d/100-etcd-bootstrap.conf

  # Never forget to clean up behind you ;-)
  rm -f "$MODULE_PATH/resources/100-etcd-bootstrap.conf"
done

# Wait for the 3 etcd nodes to form a cluster (cf. the systemd start commands
# ran above in the background)
wait

echo " ((((())))) [GREAT SUCCESS] ETCD BOOTSTRAP COMPLETE AND SUCCESSFUL, HAVE FUN ! "

exit 0
