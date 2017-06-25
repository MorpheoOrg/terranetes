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
  description = "The CoreOS AMI id to use for our Kubernetes master nodes."
  type        = "string"
}

variable "cloud_config_bucket" {
  description = "The bucket in which to store your instances cloud-config files."
  type        = "string"
}

variable "etcd_version" {
  description = "The etcd version to use (>3.1.0)"
  default     = "v3.1.5"
  type        = "string"
}

variable "hyperkube_tag" {
  description = "The version of Hyperkube to use (should be a valid tag of the official CoreOS image for Kubelet, see here: https://quay.io/repository/coreos/hyperkube?tab=tags)."
  type        = "string"
  type        = "string"
}

variable "k8s_master_instance_type" {
  description = "The EC2 instance type to use for Kubernetes master nodes."
  default     = "t2.micro"
  type        = "string"
}

variable "k8s_master_disk_size" {
  description = "The amount of disk space to use on Kubernetes master instances."
  default     = 16
  type        = "string"
}

variable "k8s_master_instance_count" {
  description = "The number of Kubernetes masters to use (at least 2 if you seek to achieve high availability)."
  default     = 2
  type        = "string"
}

variable "k8s_master_asg_health_check_type" {
  description = "The health check type to use on master autoscaling group (EC2 or ELB)"
  default     = "EC2"
  type        = "string"
}

variable "k8s_master_asg_health_check_grace_period" {
  description = "The kubernetes masters' health check grace period"
  default     = "600"
  type        = "string"
}

variable "k8s_master_endpoint" {
  description = "The URL used to reach the Kubernetes master cluster."
  type        = "string"
}

variable "etcd_endpoint" {
  description = "The etcd load-balancer endpoint"
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

variable "k8s_master_iam_role_name" {
  description = "The name of the IAM role to attach to Kubernetes master nodes."
  type        = "string"
}

variable "k8s_master_iam_profile_arn" {
  description = "The ARN of the instance profile to attach to Kubernetes master nodes."
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

variable "internal_domain" {
  description = "The internal domain name suffix to be added to your etcd & k8s master ELBs (ex. company.int)"
}

variable "terraform_ssh_key_path" {
  description = "Local path to the SSH key terraform will use to bootstrap your etcd cluster and tunnel to the Kubernetes UI."
  type        = "string"
}

variable "k8s_tls_cakey" {
  description = "The private key of the CA signing kubernetes API & worker certs"
  type        = "string"
}

variable "k8s_tls_cacert" {
  description = "The public key the CA signing kubernetes API & worker certs"
  type        = "string"
}

variable "k8s_tls_apikey" {
  description = "The private key of the Kubernetes APIServer"
  type        = "string"
}

variable "k8s_tls_apicert" {
  description = "The public key of the Kubernetes APIServer"
  type        = "string"
}

variable "dependency_hooks" {
  description = "A list of resource ids this module's autoscaling group depends on."
  type        = "string"
  default     = ""
}

variable "usernames" {
  description = "A list of usernames that will be able to SSH onto your instances through the bastion host."
  type        = "list"
}

variable "userkeys" {
  description = "The list of SSH keys your users will use (must appear in the same order as the one defined by the \"usernames\" variable)."
  type        = "list"
}

output "k8s_master_endpoint" {
  value = "${aws_route53_record.k8s_master_internal.name}"
}

output "dependency_hook" {
  value = "${null_resource.dependency_hook.id}"
}
