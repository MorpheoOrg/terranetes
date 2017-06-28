/*
 *  Maintainer: Étienne Lafarge <etienne@rythm.co>
 *   Copyright (C) 2017 Morpheo Org - Rythm SAS
 *
 *  see https://github.com/MorpheoOrg/terranetes/COPYRIGHT
 *  and https://github.com/MorpheoOrg/terranetes/LICENSE
 *  for more information.
 */

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
  description = "The CoreOS AMI id to use for our etcd instances."
  type        = "string"
}

variable "cloud_config_bucket" {
  description = "The bucket in which to store your instances cloud-config files."
}

variable "etcd_version" {
  description = "The etcd version to use (>3.1.0)"
  default     = "v3.1.5"
}

variable "etcd_instance_type" {
  description = "The EC2 instance type to use for etcd nodes."
  default     = "t2.micro"
}

variable "etcd_instance_count" {
  description = "The number of etcd nodes to use (at least 3 is recommended)."
  default     = 3
}

variable "etcd_disk_size" {
  description = "Disk size on etcd nodes."
  default     = 16
}

variable "etcd_asg_health_check_type" {
  description = "\"EC2\" or \"ELB\". If ELB is chosen, nodes with an unhealthy etcd instance will be killed"
  default     = "EC2"
  type        = "string"
}

variable "etcd_asg_health_check_grace_period" {
  description = "Health check grace period for etcd nodes"
  default     = "300"
  type        = "string"
}

variable "etcd_health_key" {
  description = "etcd key whose presence indicates that a node is healthy"
  default     = "etcd_cluster_healthy"
  type        = "string"
}

variable "private_subnet_ids" {
  description = "The ids of public subnets to spread the etcd cluster accross)."
  type        = "list"
}

variable "sg_vpn_id" {
  description = "The id of the security group that rules inside our VPN."
  type        = "string"
}

variable "etcd_iam_role_name" {
  description = "The name of the IAM role to attach to etcd nodes."
  type        = "string"
}

variable "etcd_iam_profile_arn" {
  description = "The ARN of the instance profile to attach to etcd nodes."
  type        = "string"
}

variable "route53_internal_zone_id" {
  description = "The id of the internal DNS zone to record our load-balancer routes into."
  type        = "string"
}

variable "bastion_ip" {
  description = "The IP of the bastion host Terraform will use to reach the etcd instances."
  type        = "string"
}

variable "bastion_ssh_port" {
  description = "The port to use to SSH onto your bastion host (avoid using 22 or 2222, a lot of bots are keeping on trying to scan this ports with random usernames and passwords and it tends to fill the SSHD logs a bit too much sometimes...)"
  type        = "string"
}

variable "terraform_ssh_key_path" {
  description = "Local path to the SSH key terraform will use to bootstrap your etcd cluster and tunnel to the Kubernetes UI."
  type        = "string"
}

variable "internal_domain" {
  description = "The internal domain name suffix to be added to your etcd & k8s master ELBs (ex. company.int)"
}

variable "usernames" {
  description = "A list of usernames that will be able to SSH onto your instances through the bastion host."
  type        = "list"
}

variable "userkeys" {
  description = "The list of SSH keys your users will use (must appear in the same order as the one defined by the \"usernames\" variable)."
  type        = "list"
}

variable "extra_units" {
  description = "Extra unit files (don't forget the 4-space indentation) to run on the etcd nodes"
  type        = "list"
  default     = []
}

variable "extra_files" {
  description = "Extra files (don't forget the 2-space indentation) to be put on the etcd nodes"
  type        = "list"
  default     = []
}

output "etcd_endpoint" {
  value = "http://${aws_route53_record.etcd_internal.name}:2379"
}

output "k8s_master_endpoint" {
  value = "k8s.${var.cluster_name}.${var.internal_domain}"
}

output "dependency_hook" {
  value = "${null_resource.dependency_hook.id}"
}
