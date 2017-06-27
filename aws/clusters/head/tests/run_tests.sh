#!/bin/bash

# Runs the test suite on our Kubernetes cluster

## CHECKS & ENVIRONMENT SETUP ##

if [[ -z "${TNTEST_CLOUD_CONFIG_BUCKET}" ]]; then
  echo "[ERROR] TNTEST_CLOUD_CONFIG_BUCKET env. var. must be set"
  exit 1
fi
if [[ -z "${TNTEST_AWS_ACCOUNT_ID}" ]]; then
  echo "[ERROR] TNTEST_AWS_ACCOUNT_ID env. var. must be set"
  exit 1
fi

TNTEST_CLUSTER_NAME="${TNTEST_CLUSTER_NAME:-"test"}"
TNTEST_VPC_NUMBER="${TNTEST_VPC_NUMBER:-42}"
TNTEST_VPC_REGION="${TNTEST_VPC_REGION:-"eu-west-2"}"
TNTEST_BASTION_SSH_PORT="${TNTEST_BASTION_SSH_PORT:-6969}"
TNTEST_PRIVATE_KEY_PATH="${TNTEST_PRIVATE_KEY_PATH:-"$HOME/.ssh/terraform"}"
TNTEST_COREOS_AMI_PATTERN="${TNTEST_COREOS_AMI_PATTERN:-"CoreOS-stable-*"}"
TNTEST_DOMAIN="${TNTEST_DOMAIN:-"terranetes.int"}"
TNTEST_ETCD_VERSION="${TNTEST_ETCD_VERSION:-"v3.1.5"}"
TNTEST_ETCD_NODE_COUNT="${TNTEST_ETCD_NODE_COUNT:-3}"
TNTEST_HYPERKUBE_TAG="${TNTEST_HYPERKUBE_TAG:-v1.6.2_coreos.0}"

echo "[INFO] Allow this machine's external IP to connect to the test infrastructure"
external_ip="$(curl ipecho.net/plain; echo)"

cat <<EOF > ./terraform.tfvars
test_aws_account_id = "$TNTEST_AWS_ACCOUNT_ID"
test_private_key_path = "$TNTEST_PRIVATE_KEY_PATH"
test_vpc_name = "$TNTEST_CLUSTER_NAME"
test_vpc_region = "$TNTEST_VPC_REGION"
test_vpc_number = "$TNTEST_VPC_NUMBER"
test_cloud_config_bucket = "$TNTEST_CLOUD_CONFIG_BUCKET"
test_internal_domain= "$TNTEST_DOMAIN"
test_bastion_ssh_port= "$TNTEST_BASTION_SSH_PORT"
test_cluster_name = "$TNTEST_CLUSTER_NAME"
test_coreos_ami_pattern = "$TNTEST_COREOS_AMI_PATTERN"
test_etcd_version = "$TNTEST_ETCD_VERSION"
test_etcd_node_count = "$TNTEST_ETCD_NODE_COUNT"
test_hyperkube_image = "$TNTEST_HYPERKUBE_TAG"
test_from_ip = "$external_ip"
EOF

# Check for aws CLI
echo "[INFO] Checking for AWS CLI installation"
if [[ "$(which aws || echo "argh")" == "argh" ]]; then
  echo "    [ERROR] AWS CLI isn't installed on this machine. This is required by our Terraform code. Please install it."
  exit 1
fi

# Check for terraform command
echo "[INFO] Checking terraform installation"
if [[ "$(which terraform || echo "argh")" == "argh" ]]; then
  echo "    [ERROR] Terraform isn't installed on this machine. This is required by our Terraform code. Please install it."
  exit 2
fi

# Check for Terraform-specific public/private key pair
echo "[INFO] Checking for presence of terraform SSH keypair under $TNTEST_PRIVATE_KEY_PATH(.pub)"
if [[ ! -f "$TNTEST_PRIVATE_KEY_PATH" || ! -f "$TNTEST_PRIVATE_KEY_PATH.pub"  ]]; then
  echo "    [ERROR] Running tests requires you to generate a $TNTEST_PRIVATE_KEY_PATH/$TNTEST_PRIVATE_KEY_PATH.pub SSH key pair. They seem to be missing :) ssh-keygen is your friend."
  exit 3
fi

case "$1" in
  setup)
    echo "[INFO] Setting up test environment..."

    echo "[INFO] Generating TLS certificates for test cluster..."
    ../scripts/tls_gen.sh "$TNTEST_CLUSTER_NAME" "$TNTEST_DOMAIN" "10.$((TNTEST_VPC_NUMBER + 1)).128.1"

    echo "[INFO] Generating terraform plan"
    terraform get && terraform plan
    echo "[INFO] Applying plan... Hipster, go grab yourself some artisan Coffee"
    terraform get && echo "yes" | terraform apply

    exit 0
    ;;

  teardown)
    echo "[INFO] Tearing down test environment... "

    echo "[INFO] Generating terraform destroy plan... "
    terraform get && terraform plan -destroy
    echo "[INFO] Tearing down test environment... "
    terraform get && echo "yes" | terraform destroy

    # Note: sometimes, destroying the NAT gateway times out
    # Running terraform destroy twice does the trick though
    terraform get && echo "yes" | terraform destroy

    echo "[INFO] Removing TLS certs..."
    rm -rf ./tls

    exit 0
    ;;

  test)
    echo "[INFO] Running tests !!!!"
    ./test_suite.sh "$TNTEST_PRIVATE_KEY_PATH" "$TNTEST_BASTION_SSH_PORT" "$TNTEST_VPC_REGION" bastion "$TNTEST_CLUSTER_NAME" "$TNTEST_DOMAIN" 3
    exit "$?"
    ;;

  *)
    echo "[ERROR] Unknown command $1. Available commands are setup, test and teardown."
    exit 50
    ;;
esac

