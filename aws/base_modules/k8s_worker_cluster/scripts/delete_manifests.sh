#!/bin/bash

# Connects to the cluster # TODO: (put that in a separate script to avoid code duplication)
K8S_CON_SCRIPT="$1"
BASTION_SSH_PORT="$2"
TERRAFORM_KEYFILE="$3"
CLUSTER_NAME="$4"
INTERNAL_DOMAIN="$5"
BASTION_INSTANCE_NAME="$6"
AWS_REGION="$7"

set -e
echo " ((((())))) Configuring local kubectl to talk to the APIServer..."
"$K8S_CON_SCRIPT" terraform "$TERRAFORM_KEYFILE" "$BASTION_SSH_PORT" "$AWS_REGION" "$BASTION_INSTANCE_NAME" "$CLUSTER_NAME" "$INTERNAL_DOMAIN"

echo " ((((())))) Deleting Kubernetes manifests..."
set +e
i=8
while [[ ! -z "${!i}" ]]; do
  echo "${!i}" > manifest.yml
  kubectl delete -f manifest.yml
  i=$((i+1))
done
set -e

# Bye
killall ssh
