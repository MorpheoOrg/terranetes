#!/bin/bash

# Runs the test suite on our etcd cluster
# TODO: use a initd like switcd case for setup, teardown and test entrypoints, checks should be run all the time

## CHECKS ##

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
echo "[INFO] Checking for presence of terraform SSH keypair in ~/.ssh/"
if [[ ! -f ~/.ssh/terraform || ! -f ~/.ssh/terraform.pub  ]]; then
  echo "    [ERROR] Running tests requires you to generate a terraform/terraform.pub SSH key pair in ~/.ssh/. They seem to be missing :) ssh-keygen is your friend."
  exit 3
fi

printf "\n"

case "$1" in
  setup)
    echo "[INFO] Setting up test environment... "
    echo "[INFO] Allow this machine's external IP to connect to the test infrastructure"
    external_ip="$(curl ipecho.net/plain; echo)"
    export TF_VAR_test_from_ip="${external_ip}"

    # echo "[INFO] Let's generate TLS certs for our test infrastructure"
    # rm -rf ./tls
    # ../../aws/scripts/tls-gen.sh test-cluster terranetes.int 10.101.128.1
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

    echo "[INFO] Removing TLS certs"
    rm -rf ./tls

    exit 0
    ;;

  test)
    echo "[INFO] Running tests !!!!"

    exit 0
    ;;

  *)
    echo "[ERROR] Unknown command $1. Available commands are setup, test and teardown."
    exit 50
    ;;
esac

