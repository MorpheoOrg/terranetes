/*
 * Parameters of our Kubernetes cluster in Dublin for Morpheo
 */

provider "aws" {
  region              = "${var.test_vpc_region}"
  allowed_account_ids = ["${var.test_aws_account_id}"]

  # This file should contain credentials for the Terraform user. Create new
  # ones in AWS IAM for that user if you need to.
  profile = "default"
}

variable "test_aws_account_id" {
  description = "AWS account ID used for testing (suggestion: use an account dedicated to that purpose)."
  type        = "string"
}

variable "test_private_key_path" {
  type        = "string"
  description = "The path to your private SSH key in order to jump to the infrastructure to bootstrap the etcd cluster. Note that we'll soon rather use the AWS API for that."
}

### KUBERNETES CLUSTER PARAMETERS ###
variable "test_vpc_name" {
  type        = "string"
  description = "The name of the VPC to be created (this is a variable so that multiple tests can be run in multiple VPCs in parralel to fasten this long CI a bit."
  default     = "terranetes-test"
}

variable "test_vpc_number" {
  type        = "string"
  description = "The VPC will span the CIDR 10.<vpc_number>.0.0/17"
  default     = 100
}

variable "test_vpc_region" {
  default     = "eu-west-2"
  type        = "string"
  description = "The region to spawn the test cluster into"
}

variable "test_cloud_config_bucket" {
  type        = "string"
  description = "The bucket in which your cloud-config YAMLs will be stored"
}

variable "test_bastion_ssh_port" {
  default     = 6969
  description = "The SSH port to use to connect to the bastion"
  type        = "string"
}

variable "test_internal_domain" {
  default     = "terranetes.int"
  description = "Internal domain to use for etcd and kubernetes master"
  type        = "string"
}

variable "test_cluster_name" {
  default     = "test"
  type        = "string"
  description = "Kubernetes cluster name to use to run the tests"
}

### CoreOS configuration ###
variable "test_coreos_ami_owner_id" {
  description = "The ID of the owner of the CoreOS image you want to use on the AWS marketplace (or yours if you're using your own AMI)."

  # CoreOS' official AWS id
  default = "595879546273"
  type    = "string"
}

variable "test_coreos_ami_pattern" {
  description = "The AMI pattern to use (it can be a full name or contain wildcards, default to the last release of CoreOS on the stable channel)."

  # Useful to change that to also run tests against the beta and alpha version of Container Linux
  default = "CoreOS-stable-*"
  type    = "string"
}

variable "test_hyperkube_image" {
  default     = "v1.6.2_coreos.0"
  type        = "string"
  description = "Hyperkube image to use (fetched from quay.io: https://quay.io/repository/coreos/hyperkube?tab=tags)"
}

variable "test_etcd_version" {
  default     = "v3.1.5"
  type        = "string"
  description = "Etcd version to use"
}

### IP allowed to SSH onto our test infrastructure ###
variable "test_from_ip" {
  type        = "string"
  description = "IP allowed to SSH onto the bastion"
}
