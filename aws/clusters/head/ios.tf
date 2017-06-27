/*
 *  Maintainer: Étienne Lafarge <etienne@rythm.co>
 *   Copyright (C) 2017 Morpheo Org - Rythm SAS
 *
 *  see https://github.com/MorpheoOrg/terranetes/COPYRIGHT
 *  and https://github.com/MorpheoOrg/terranetes/LICENSE
 *  for more information.
 */

variable "vpc_region" {
  description = "The AWS region to create your Kubernetes cluster into."
  type        = "string"
}

variable "vpc_name" {
  description = "Arbitrary name to give to your VPC"
  type        = "string"
}

variable "vpc_number" {
  description = "The VPC number. This will define the VPC IP range in CIDR notation as follows: 10.<vpc_number>.0.0/16"
  type        = "string"
}

variable "cluster_name" {
  description = "The name of the Kubernetes cluster to create (necessary when federating clusters)."
  type        = "string"
}

variable "usernames" {
  description = "A list of usernames that will be able to SSH onto your instances through the bastion host."
  type        = "list"
  default     = []
}

variable "userkeys" {
  description = "The list of SSH keys your users will use (must appear in the same order as the one defined by the \"usernames\" variable)."
  type        = "list"
  default     = []
}

variable "bastion_ssh_port" {
  description = "The port to use to SSH onto your bastion host (avoid using 22 or 2222, a lot of bots are keeping on trying to scan this ports with random usernames and passwords and it tends to fill the SSHD logs a bit too much sometimes...)"
  type        = "string"
}

variable "terraform_ssh_key_path" {
  description = "Local path to the SSH key terraform will use to bootstrap your etcd cluster and tunnel to the Kubernetes UI."
  type        = "string"
}

variable "trusted_cidrs" {
  description = "A list of CIDRs that will be allowed to connect to the SSH port defined by \"bastion_ssh_port\"."
  type        = "list"
}

variable "coreos_ami_owner_id" {
  description = "The ID of the owner of the CoreOS image you want to use on the AWS marketplace (or yours if you're using your own AMI)."
  default     = "595879546273"
  type        = "string"
}

variable "coreos_ami_pattern" {
  description = "The AMI pattern to use (it can be a full name or contain wildcards, default to the last release of CoreOS on the stable channel)."
  default     = "CoreOS-stable-*"
  type        = "string"
}

variable "virtualization_type" {
  type        = "string"
  default     = "hvm"
  description = "The AWS virtualization type to use (hvm or pv)"
}

variable "cloud_config_bucket" {
  description = "The name of the bucket in which to store your instances cloud-config files."
  type        = "string"
}

variable "internal_domain" {
  description = "The internal domain name suffix to be atted to your etcd & k8s master ELBs (ex. company.int)"
  type        = "string"
}

variable "etcd_version" {
  description = "The etcd version to use (>v3.1.0)"
  default     = "v3.1.5"
}

variable "etcd_instance_type" {
  description = "The EC2 instance type to use for etcd nodes."
  default     = "t2.micro"
  type        = "string"
}

variable "etcd_instance_count" {
  description = "The number of etcd nodes to use (at least 3 is recommended)."
  type        = "string"
  default     = 3
}

variable "etcd_asg_health_check_type" {
  description = "The health check type to use for the etcd ASG (EC2 or ELB)"
  default     = "EC2"
  type        = "string"
}

variable "k8s_master_asg_health_check_grace_period" {
  description = "The kubernetes masters' health check grace period"
  default     = "600"
  type        = "string"
}

variable "hyperkube_tag" {
  description = "The version of Hyperkube to use (should be a valid tag of the official CoreOS image for Kubelet, see here: https://quay.io/repository/coreos/hyperkube?tab=tags)."
  type        = "string"
}

variable "k8s_master_instance_type" {
  description = "The EC2 instance type to use for Kubernetes master nodes."
  default     = "t2.micro"
  type        = "string"
}

variable "k8s_master_instance_count" {
  description = "The number of Kubernetes nodes to run (2 is recommended)."
  type        = "string"
  default     = 2
}

variable "k8s_master_asg_health_check_type" {
  description = "The number of Kubernetes masters to use (at least 2 if you seek to achieve high availability)."
  default     = "EC2"
  type        = "string"
}

variable "k8s_master_disk_size" {
  description = "The disk size for Kubernetes master nodes (in GB)"
  type        = "string"
  default     = "16"
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

variable "bastion_extra_units" {
  description = "Extra unit files (don't forget the 4-space indentation) to run on the bastion host"
  type        = "list"
  default     = []
}

variable "etcd_extra_units" {
  description = "Extra unit files (don't forget the 4-space indentation) to run on the etcd nodes"
  type        = "list"
  default     = []
}

variable "etcd_extra_files" {
  description = "Extra files (don't forget the 2-space indentation) to be put on the etcd nodes"
  type        = "list"
  default     = []
}

## KUBERNETES MANIFESTS VARIABLES ##

variable "kube_dns_replicas" {
  description = "Number of kube-dns replicas to run"
  type        = "string"
  default     = "3"
}

variable "kube_dns_image" {
  description = "Docker image to use for kube-dns"
  type        = "string"
  default     = "gcr.io/google_containers/kubedns-amd64:1.9"
}

variable "kube_dns_dnsmasq_image" {
  description = "Docker image to use for kube-dns dnsmasq"
  type        = "string"
  default     = "gcr.io/google_containers/kube-dnsmasq-amd64:1.4"
}

variable "kube_dns_dnsmasq_metrics_image" {
  description = "Docker image to use for kube-dns dnsmasq metrics"
  type        = "string"
  default     = "gcr.io/google_containers/dnsmasq-metrics-amd64:1.0"
}

variable "kube_dns_exechealthz_image" {
  description = "Docker image to use for kube-dns exechealthz"
  type        = "string"
  default     = "gcr.io/google_containers/exechealthz-amd64:1.2"
}

variable "kube_dashboard_image" {
  description = "Docker image to use for kubernetes-dashboard"
  type        = "string"
  default     = "gcr.io/google_containers/kubernetes-dashboard-amd64:v1.6.1"
}

## OUTPUTS ##

output "vpc_id" {
  value = "${module.foundations.vpc_id}"
}

output "public_route_table_id" {
  value = "${module.foundations.public_route_table_id}"
}

output "private_route_table_id" {
  value = "${module.foundations.private_route_table_id}"
}

output "coreos_ami_id" {
  value = "${module.foundations.coreos_ami_id}"
}

output "cloud_config_bucket" {
  value = "${module.foundations.cloud_config_bucket}"
}

output "etcd_endpoint" {
  value = "${module.etcd_cluster.etcd_endpoint}"
}

output "k8s_master_endpoint" {
  value = "${module.k8s_master_cluster.k8s_master_endpoint}"
}

output "k8s_worker_iam_role_name" {
  value = "${module.foundations.k8s_worker_iam_role_name}"
}

output "k8s_worker_profile_arn" {
  value = "${module.foundations.k8s_worker_profile_arn}"
}

output "private_subnet_ids" {
  value = "${module.foundations.private_subnet_ids}"
}

output "public_subnet_ids" {
  value = "${module.foundations.public_subnet_ids}"
}

output "route53_internal_zone_id" {
  value = "${module.foundations.route53_internal_zone_id}"
}

output "sg_vpn_id" {
  value = "${module.foundations.sg_vpn_id}"
}

output "dependency_hook" {
  value = "${module.etcd_cluster.dependency_hook},${module.k8s_master_cluster.dependency_hook}"
}
