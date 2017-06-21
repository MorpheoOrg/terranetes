#!/bin/bash

#
# Waits for the kubernetes master to be available from the bastion host or
# times out with an error code after 10 minutes
#
# Maintainer: Étienne Lafarge <etienne@rythm.co>
#

BASTION_IP="$1"
BASTION_SSH_PORT="$2"
TERRAFORM_KEYFILE="$3"
CLUSTER_NAME="$4"
INTERNAL_DOMAIN="$5"

echo " ((((())))) Waiting for the Kubernetes master cluster to be available..."

echo " ((((())))) Configuring local kubectl to talk to the APIServer..."
ssh -oStrictHostKeyChecking=no -t -t -A -L "6443:k8s.$CLUSTER_NAME.$INTERNAL_DOMAIN:443" -p "$BASTION_SSH_PORT" -i "$TERRAFORM_KEYFILE" terraform@"$BASTION_IP" &
tlsdir="./tls/${CLUSTER_NAME}"
echo "Configuring Kube Control ! (binding local kubectl to the remote one on AWS)"
kubectl config set-cluster "$CLUSTER_NAME" --server="https://k8s.$CLUSTER_NAME.$INTERNAL_DOMAIN:6443" --certificate-authority="${tlsdir}/ca.pem"
kubectl config set-credentials "$CLUSTER_NAME-default-admin" --certificate-authority="${tlsdir}/ca.pem" --client-key="${tlsdir}/administrator.key" --client-certificate="${tlsdir}/administrator.pem"
kubectl config set-context "$CLUSTER_NAME-default-system" --cluster="$CLUSTER_NAME" --user="$CLUSTER_NAME-default-admin"
kubectl config use-context "$CLUSTER_NAME-default-system"
sleep 60s

consecutively_successful_checks=0
while [[ "$consecutively_successful_checks" -le 10 ]]; do
  "kubectl cluster-info"
  status="$?"
  if [[ "$status" -eq 0 ]]; then
    consecutively_successful_checks=$((consecutively_successful_checks+1))
  else
    echo " ((((())))) o0o0 >>> Failed to reach Kubernetes APIServer, retrying in 10s..."
    consecutively_successful_checks=0
    sleep 10s
  fi
done

exit 0
