/*
 *  Maintainer: Étienne Lafarge <etienne@rythm.co>
 *   Copyright (C) 2017 Morpheo Org - Rythm SAS
 *
 *  see https://github.com/MorpheoOrg/terranetes/COPYRIGHT
 *  and https://github.com/MorpheoOrg/terranetes/LICENSE
 *  for more information.
 */

variable "enable" {
  description = "If set to 0, these cluster's ASG won't be created"
  type        = "string"
  default     = 1
}

variable "vpc_name" {
  description = "Arbitrary name to give to your VPC"
  type        = "string"
}

variable "vpc_number" {
  description = "The VPC number. This will define the VPC IP range in CIDR notation as follows: 10.<vpc_number>.0.0/16"
  type        = "string"
}

variable "vpc_region" {
  description = "The AWS region in which to deploy your cluster & VPC."
  type        = "string"
}

variable "cluster_name" {
  description = "The name of the Kubernetes cluster to create (necessary when federating clusters)."
  type        = "string"
}

variable "coreos_ami_id" {
  description = "The CoreOS AMI id to use for our Kubernetes worker instances."
  type        = "string"
}

variable "cloud_config_bucket" {
  description = "The bucket in which to store your instances cloud-config files."
  type        = "string"
}

variable "hyperkube_tag" {
  description = "The version of Hyperkube to use (should be a valid tag of the official CoreOS image for Kubelet, see here: https://quay.io/repository/coreos/hyperkube?tab=tags)."
  type        = "string"
}

variable "worker_group_name" {
  description = "The name you'd like to give to this worker group"
  type        = "string"
}

variable "node_instance_type" {
  description = "The EC2 instance type to use for Kubernetes workers."
  default     = "t2.micro"
}

variable "min_asg_size" {
  description = "The minimum size of the worker pool"
  type        = "string"
}

variable "max_asg_size" {
  description = "The maximum size of the worker pool"
  type        = "string"
}

variable "k8s_node_labels" {
  description = "A comma separated list of node labels under the form key=value"
  type        = "string"
}

variable "k8s_node_disk_size" {
  description = "The amount of disk space to use on Kubernetes API nodes."
  default     = 30
}

variable "k8s_master_endpoint" {
  description = "The URL used to reach the Kubernetes master cluster."
  type        = "string"
}

variable "etcd_endpoint" {
  description = "The URL used to reach the etcd cluster."
  type        = "string"
}

variable "private_subnet_ids" {
  description = "The ids of private subnets to spread this private worker cluster accross)."
  type        = "list"
}

variable "sg_ids" {
  description = "The id of the security groups you'd like to add to nodes (useful for open your public services ports to internet facing load balancers). Don't forget to add the VPN security group there too."
  type        = "list"
}

variable "k8s_worker_iam_role_name" {
  description = "The name of the IAM role to attach to Kubernetes worker nodes."
  type        = "string"
}

variable "k8s_worker_profile_arn" {
  description = "The ARN of the instance profile to attach to Kubernetes worker nodes."
  type        = "string"
}

variable "bastion_ip" {
  description = "The IP Adress of a bastion host"
  type        = "string"
}

variable "bastion_ssh_port" {
  description = "The port to use to SSH onto your bastion host (avoid using 22 or 2222, a lot of bots are keeping on trying to scan this ports with random usernames and passwords and it tends to fill the SSHD logs a bit too much sometimes...)"
  type        = "string"
}

variable "internal_domain" {
  description = "The internal domain name suffix to be added to your etcd & k8s master ELBs (ex. company.int)"
}

variable "terraform_ssh_key_path" {
  description = "Local path to the SSH key terraform will use to bootstrap your etcd cluster and tunnel to the Kubernetes UI."
  type        = "string"
}

variable "k8s_tls_cakey" {
  description = "The private key of the CA signing kubernetes worker certs"
  type        = "string"
}

variable "k8s_tls_cacert" {
  description = "The public key the CA signing kubernetes worker certs"
  type        = "string"
}

variable "usernames" {
  description = "A list of usernames that will be able to SSH onto your instances through the bastion host."
  type        = "list"
}

variable "userkeys" {
  description = "The list of SSH keys your users will use (must appear in the same order as the one defined by the \"usernames\" variable)."
  type        = "list"
}

variable "dependency_hooks" {
  description = "A list of resource ids this module's autoscaling group depends on."
  type        = "string"
  default     = ""
}

variable "extra_units" {
  description = "Extra systemd unit files (don't forget the 4-space indentation) to run on these nodes"
  type        = "list"
  default     = []
}

variable "extra_files" {
  description = "Extra files (don't forget the 4-space indentation) to put on these nodes"
  type        = "list"
  default     = []
}

variable "load_balancers" {
  description = "A list of load-balancers to attach to this cluster's auto-scaling group"
  type        = "list"
  default     = []
}

variable "kubernetes_manifests" {
  description = "A list of kubernetes YAML manifests to push once this ASG has been created"
  type        = "list"
  default     = []
}
