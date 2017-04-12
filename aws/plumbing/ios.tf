/*
 * Inputs (variables) and outputs for our AWS cluster-config module
 * defining VPC, subnet, connectivity instances and stuff.
 *
 *        ---------------------------
 *
 *  Maintainer: Étienne Lafarge <etienne@rythm.co>
 *   Copyright (C) 2017 Morpheo Org - Rythm SAS
 *
 *  see https://github.com/MorpheoOrg/terranetes/COPYRIGHT
 *  and https://github.com/MorpheoOrg/terranetes/LICENSE
 *  for more information.
 */
variable "vpc_name" {
  description = "Arbitrary name to give to your VPC"
}

variable "vpc_number" {
  description = "The VPC number. This will define the VPC IP range in CIDR notation as follows: 10.<vpc_number>.0.0/16"
}

variable "vpc_region" {
  description = "The AWS region in which to deploy your cluster & VPC."
}

variable "cluster_name" {
  description = "The name of the Kubernetes cluster to create (necessary when federating clusters)."
  type = "string"
}

variable "usernames" {
  description = "A list of usernames that will be able to SSH onto your instances through the bastion host."
  type = "list"
}

variable "userkeys" {
  description = "The list of SSH keys your users will use (must appear in the same order as the one defined by the \"usernames\" variable)."
  type = "list"
}

variable "bastion_ssh_port" {
  description = "The port to use to SSH onto your bastion host (avoid using 22 or 2222, a lot of bots are keeping on trying to scan this ports with random usernames and passwords and it tends to fill the SSHD logs a bit too much sometimes...)"
  type = "string"
}

variable "trusted_cidrs" {
  description = "A list of CIDRs that will be allowed to connect to the SSH port defined by \"bastion_ssh_port\"."
  type = "list"
}

variable "coreos_ami_owner_id" {
  description = "The ID of the owner of the CoreOS image you want to use on the AWS marketplace (or yours if you're using your own AMI)."
}
variable "coreos_ami_pattern" {
  description = "The AMI pattern to use (it can be a full name or contain wildcards, default to the last release of CoreOS on the stable channel)."
}

variable "cloud_config_bucket" {
  description = "The name of the bucket in which to store your instances cloud-config files."
}

variable "internal_domain" {
  description = "The internal domain name suffix to be atted to your etcd & k8s master ELBs (ex. company.int)"
}

variable "bastion_extra_units" {
  description = "Extra unit files (don't forget the 4-space indentation) to run on the bastion host"
  type = "list"
  default = []
}

output "vpc_id" {
  value = "${aws_vpc.main.id}"
}

output "public_route_table_id" {
  value = "${aws_route_table.public.id}"
}

output "private_route_table_id" {
  value = "${aws_route_table.private.id}"
}

output "public_subnet_ids" {
  value = ["${aws_subnet.public.*.id}"]
}

output "private_subnet_ids" {
  value = ["${aws_subnet.private.*.id}"]
}

output "sg_trusted_ips_id" {
  value = "${aws_security_group.trusted_ips.id}"
}

output "sg_vpn_id" {
  value = "${aws_security_group.vpn.id}"
}

output "etcd_iam_role_name" {
  value = "${aws_iam_role.etcd.name}"
}

output "etcd_iam_profile_arn" {
  value = "${aws_iam_instance_profile.etcd.arn}"
}

output "k8s_master_iam_role_name" {
  value = "${aws_iam_role.k8s_master.name}"
}

output "k8s_master_profile_arn" {
  value = "${aws_iam_instance_profile.k8s_master.arn}"
}

output "k8s_worker_iam_role_name" {
  value = "${aws_iam_role.k8s_worker.name}"
}

output "k8s_worker_profile_arn" {
  value = "${aws_iam_instance_profile.k8s_worker.arn}"
}

output "bastion_ip" {
  value = "${aws_instance.bastion.public_ip}"
}

output "cloud_config_bucket" {
  value = "${aws_s3_bucket.cloud_config.bucket}"
}

output "route53_internal_zone_id" {
  value = "${aws_route53_zone.internal.id}"
}

output "coreos_ami_id" {
  value = "${data.aws_ami.coreos_stable.id}"
}
