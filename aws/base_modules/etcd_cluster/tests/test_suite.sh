#!/bin/bash

# Test suite for the etcd cluster.

PRIVATE_SSH_KEY_PATH="$1"
SSH_PORT="$2"
AWS_REGION="$3"
BASTION_INSTANCE_NAME="$4"
CLUSTER_NAME="$5"
CLUSTER_DOMAIN="$6"
EXPECTED_NUMBER_OF_ETCD_NODES="$7"

## SETUP

echo "[ETCD CLUSTER TEST SETUP 1/3] Get the bastion IP by name"
bastion_ip_address=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=$BASTION_INSTANCE_NAME" "Name=instance-state-name,Values=running" "Name=tag:cluster-name,Values=$CLUSTER_NAME"\
    --query 'Reservations[0].Instances[0].PublicIpAddress')

bastion_ip_address=$(sed 's/"//g' <<< "$bastion_ip_address")
echo "[ETCD CLUSTER TEST SETUP 1/3] Done: bastion IP is $bastion_ip_address"

echo "[ETCD CLUSTER TEST SETUP 2/3] Get the IDs and IPs of the etcd hosts"
ASG_NAME="etcd-$CLUSTER_NAME"
update_etcd_ip_list () {
  etcd_instance_ids_json=$(aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names "$ASG_NAME" \
      --region "$AWS_REGION" \
      --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId' \
      --no-paginate)
  etcd_instance_ids=($(sed 's/,/ /g' <<< "$(sed 's/[][ "]//g' <<< "$(tr '\n' ' ' <<< "$etcd_instance_ids_json")")"))

  etcd_ip_addresses=$(aws ec2 describe-instances \
      --region "$AWS_REGION" \
      --instance-ids "${etcd_instance_ids[@]}" \
      --query 'Reservations[*].Instances[*].PrivateIpAddress')

  etcd_ip_addresses=($(sed 's/,/ /g' <<< "$(sed 's/[][ "]//g' <<< "$(tr '\n' ' ' <<< "$etcd_ip_addresses")")"))
}
update_etcd_ip_list
echo "[ETCD CLUSTER TEST SETUP 2/3] Done: etcd instance IDS: ${etcd_instance_ids[*]}; etcd instance IPs: ${etcd_ip_addresses[*]}"

echo "[ETCD CLUSTER TEST SETUP 3/3] Setup SSH commands to jump to the bastion host/etcd hosts"
proxy_ssh_cmd="ssh  -o 'StrictHostKeyChecking=no' -o 'ConnectTimeout=5' -o 'BatchMode=yes' -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -q -l terraform -W '[%h]:%p' $bastion_ip_address"
bastion_ssh_cmd=(ssh -p $SSH_PORT -i $PRIVATE_SSH_KEY_PATH -o "StrictHostKeyChecking=no" -o "ConnectTimeout=5" -o "BatchMode=yes" -q "terraform@$bastion_ip_address")
etcd_ssh_cmd=(ssh -o "StrictHostKeyChecking=no" -o "ConnectTimeout=5" -o "BatchMode=yes" -o "ProxyCommand $proxy_ssh_cmd")
echo "[ETCD CLUSTER TEST SETUP 3/3] Done"

## TESTS
ETCD_ENDPOINT="http://etcd.$CLUSTER_NAME.$CLUSTER_DOMAIN:2379"
RESPAWN_TIMEOUT=600

wait_for_healthy_cluster_or_die () {
  local start_date
  start_date="$(date +"%s")"
  local now
  now="$(date +"%s")"
  local cluster_healthy=false

  while [[ "$((now - start_date))" -le "$RESPAWN_TIMEOUT" ]]; do
    number_of_etcd_nodes="$("${bastion_ssh_cmd[@]}" etcdctl --endpoints="$ETCD_ENDPOINT" cluster-health | grep -c "got healthy result from")"
    if [[ "$number_of_etcd_nodes" -eq "$EXPECTED_NUMBER_OF_ETCD_NODES" ]]; then
      cluster_healthy=true
      break
    fi
    now="$(date +"%s")"
    echo "                                Waiting for cluster_health (expected count: $EXPECTED_NUMBER_OF_ETCD_NODES, actual: $number_of_etcd_nodes). Time left: "$((RESPAWN_TIMEOUT - now + start_date))"s..."
    sleep 10s
  done

  if [[ ! "$cluster_healthy" ]]; then
    echo "                                Full cluster health hasn't been restored within ${RESPAWN_TIMEOUT}s..."
    exit 20
  fi
}

echo "[ETCD CLUSTER TEST 01] etcd cluster is healthy and has appropriate node count"
number_of_etcd_nodes="$("${bastion_ssh_cmd[@]}" etcdctl --endpoints="$ETCD_ENDPOINT" cluster-health | grep -c "got healthy result from")"
cluster_health="$?"
if [[ "$cluster_health" -ne 0 ]]; then
  echo "[ETCD CLUSTER TEST 01][FAILURE] Cluster is unhealthy"
  exit 10
fi
if [[ "$number_of_etcd_nodes" -ne "$EXPECTED_NUMBER_OF_ETCD_NODES" ]]; then
  echo "[ETCD CLUSTER TEST 01][FAILURE] Cluster has wrong number of healthy nodes (expected: $EXPECTED_NUMBER_OF_ETCD_NODES; actual: $number_of_etcd_nodes)"
  exit 11
fi
echo "[ETCD CLUSTER TEST 01][SUCCESS] etcd cluster is healthy and has expected size"

echo "[ETCD CLUSTER TEST 02] etcd cluster is resilient to node deletion"
"${bastion_ssh_cmd[@]}" etcdctl --endpoints="$ETCD_ENDPOINT" cluster-health
aws ec2 terminate-instances --region "$AWS_REGION" --instance-ids "${etcd_instance_ids[0]}"
sleep 30s
wait_for_healthy_cluster_or_die
echo "[ETCD CLUSTER TEST 02][SUCCESS] Deleted node has been respawned on time"

echo "[ETCD CLUSTER TEST 03] etcd cluster is resilient to etcd service crashes"
update_etcd_ip_list
"${bastion_ssh_cmd[@]}" etcdctl --endpoints="$ETCD_ENDPOINT" cluster-health
"${etcd_ssh_cmd[@]}" "terraform@${etcd_ip_addresses[0]}" sudo systemctl stop etcd-member.service
sleep 30s
wait_for_healthy_cluster_or_die
echo "[ETCD CLUSTER TEST 03][SUCCESS] Crashed node has been respawned on time"

# TEST 4: cluster is resilient to data corruption
echo "[ETCD CLUSTER TEST 04] etcd cluster is resilient to data corruption (or deletion)"
update_etcd_ip_list
"${bastion_ssh_cmd[@]}" etcdctl --endpoints="$ETCD_ENDPOINT" cluster-health
"${etcd_ssh_cmd[@]}" "terraform@${etcd_ip_addresses[0]}" sudo rm -rf /var/lib/etcd/*
sleep 180s
wait_for_healthy_cluster_or_die
echo "[ETCD CLUSTER TEST 04][SUCCESS] Corrupted node has been fixed or respawned on time"
