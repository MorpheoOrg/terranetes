#!/bin/bash

#
# Creates a (persistent) SSH tunnel to all the services in our infrastructure
# You'll need to modify your /etc/hosts as well to add the internal endpoints
# set for etcd and kubernetes. (ex: 127.0.0.1 k8s.my-cluster.example.int)
#
# The command also configures kubectl if it can find it on the local machine,
# same applies to etcdctl.
#
# Maintainer: Étienne Lafarge <etienne@rythm.co>
#

USERNAME="$1"
USERKEY="$2"
SSH_PORT="$3"
AWS_REGION="$4"
BASTION_INSTANCE_NAME="$5"
CLUSTER_NAME="$6"
INTERNAL_DOMAIN="$6"

# STEP 1: finding out who the bastion is
ip_address=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=$BASTION_INSTANCE_NAME" "Name=instance-state-name,Values=running" "Name=tag:cluster-name,Values=$CLUSTER_NAME"\
    --query 'Reservations[0].Instances[0].PublicIpAddress')

ip_address=$(sed 's/"//g' <<< "$ip_address")
# ip_address="52.57.128.230"
echo "Bastion IP is: $ip_address"

echo "Killing all currently ssh sessions for user $USER. Sorry :p..."
killall ssh

echo "Creating SSH tunnels to our AWS bastions in region $AWS_REGION..."

echo "ssh -A -L -oStrictHostKeyChecking=no \"6443:k8s.$CLUSTER_NAME.$INTERNAL_DOMAIN:443\" -p \"$SSH_PORT\" -i \"$USERKEY\" \"$USERNAME\"@\"$ip_address\""

nohup ssh -oStrictHostKeyChecking=no -t -t -A -L "8080:k8s.$CLUSTER_NAME.$INTERNAL_DOMAIN:8080" -p "$SSH_PORT" -i "$USERKEY" "$USERNAME"@"$ip_address" >>/dev/null &
nohup ssh -oStrictHostKeyChecking=no -t -t -A -L "6443:k8s.$CLUSTER_NAME.$INTERNAL_DOMAIN:443" -p "$SSH_PORT" -i "$USERKEY" "$USERNAME"@"$ip_address" >>/dev/null &
nohup ssh -oStrictHostKeyChecking=no -t -t -A -L "2379:etcd.$CLUSTER_NAME.$INTERNAL_DOMAIN:2379" -p "$SSH_PORT" -i "$USERKEY" "$USERNAME"@"$ip_address" >>/dev/null &

# Step 2: configuring kubectl
tlsdir="./tls/${CLUSTER_NAME}"
echo "Configuring Kube Control ! (binding local kubectl to the remote one on AWS)"
kubectl config set-cluster "$CLUSTER_NAME" --server="https://k8s.$CLUSTER_NAME.$INTERNAL_DOMAIN:6443" --certificate-authority="${tlsdir}/ca.pem"
kubectl config set-credentials "$CLUSTER_NAME-default-admin" --certificate-authority="${tlsdir}/ca.pem" --client-key="${tlsdir}/administrator.key" --client-certificate="${tlsdir}/administrator.pem"
kubectl config set-context "$CLUSTER_NAME-default-system" --cluster="$CLUSTER_NAME" --user="$CLUSTER_NAME-default-admin"
kubectl config use-context "$CLUSTER_NAME-default-system"
