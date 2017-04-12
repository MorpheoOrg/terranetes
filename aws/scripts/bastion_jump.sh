#!/bin/bash

#
# Opens up an SSH connection to the bastion in the given cluster.
#
# Maintainer: Étienne Lafarge <etienne@rythm.co>
#

USERNAME="$1"
USERKEY="$2"
SSH_PORT="$3"
AWS_REGION="$4"
BASTION_INSTANCE_NAME="$5"
CLUSTER_NAME="$6"

# STEP 1: finding out who the bastion is
ip_address=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=$BASTION_INSTANCE_NAME" "Name=instance-state-name,Values=running" "Name=tag:cluster-name,Values=$CLUSTER_NAME"\
    --query 'Reservations[0].Instances[0].PublicIpAddress')

ip_address=$(sed 's/"//g' <<< "$ip_address")
# ip_address="52.57.128.230"
echo "Bastion IP is: $ip_address, connecting to it"

ssh -A -p "$SSH_PORT" -i "$USERKEY" "$USERNAME"@"$ip_address"
