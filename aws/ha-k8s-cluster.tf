/*
 *                  GNU GENERAL PUBLIC LICENSE
 *                     Version 3, 29 June 2007
 *
 *  Creates and manages Kubernetes clusters on AWS with Terraform
 *  Copyright (C) 2017 Morpheo Org - Rythm SAS
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *                ------------------------------
 *
 * Defines a kubernetes HA cluster on a given AWS VPC. Worker nodes needs to
 * be added aside.
 *
 * Maintainer: Étienne Lafarge <etienne@rythm.co>
 */

module "foundations" {
  source = "./plumbing"

  vpc_name            = "${var.vpc_name}"
  vpc_number          = "${var.vpc_number}"
  vpc_region          = "${var.vpc_region}"
  cluster_name        = "${var.cluster_name}"
  usernames           = ["${var.usernames}"]
  userkeys            = ["${var.userkeys}"]
  bastion_ssh_port    = "${var.bastion_ssh_port}"
  trusted_cidrs       = ["${var.trusted_cidrs}"]
  coreos_ami_owner_id = "${var.coreos_ami_owner_id}"
  coreos_ami_pattern  = "${var.coreos_ami_pattern}"
  virtualization_type = "${var.virtualization_type}"
  cloud_config_bucket = "${var.cloud_config_bucket}"
  internal_domain     = "${var.internal_domain}"
  bastion_extra_units = ["${var.bastion_extra_units}"]
}

module "etcd_cluster" {
  source = "./etcd_cluster"

  vpc_name                 = "${var.vpc_name}"
  vpc_number               = "${var.vpc_number}"
  vpc_region               = "${var.vpc_region}"
  cluster_name             = "${var.cluster_name}"
  coreos_ami_id            = "${module.foundations.coreos_ami_id}"
  cloud_config_bucket      = "${module.foundations.cloud_config_bucket}"
  etcd_version             = "${var.etcd_version}"
  etcd_instance_type       = "${var.etcd_instance_type}"
  etcd_instance_count      = "${var.etcd_instance_count}"
  sg_vpn_id                = "${module.foundations.sg_vpn_id}"
  etcd_iam_role_name       = "${module.foundations.etcd_iam_role_name}"
  etcd_iam_profile_arn     = "${module.foundations.etcd_iam_profile_arn}"
  route53_internal_zone_id = "${module.foundations.route53_internal_zone_id}"
  bastion_ip               = "${module.foundations.bastion_ip}"
  bastion_ssh_port         = "${var.bastion_ssh_port}"
  terraform_ssh_key_path   = "${var.terraform_ssh_key_path}"
  cloud_config_bucket      = "${module.foundations.cloud_config_bucket}"
  private_subnet_ids       = "${module.foundations.private_subnet_ids}"
  internal_domain          = "${var.internal_domain}"
  usernames                = ["${var.usernames}"]
  userkeys                 = ["${var.userkeys}"]
  extra_units              = ["${var.etcd_extra_units}"]
  extra_files              = ["${var.etcd_extra_files}"]
}

module "k8s_master_cluster" {
  source = "./k8s_master_cluster"

  vpc_name                   = "${var.vpc_name}"
  vpc_number                 = "${var.vpc_number}"
  vpc_region                 = "${var.vpc_region}"
  cluster_name               = "${var.cluster_name}"
  coreos_ami_id              = "${module.foundations.coreos_ami_id}"
  cloud_config_bucket        = "${module.foundations.cloud_config_bucket}"
  etcd_version               = "${var.etcd_version}"
  hyperkube_tag              = "${var.hyperkube_tag}"
  k8s_master_instance_type   = "${var.k8s_master_instance_type}"
  k8s_master_instance_count  = "${var.k8s_master_instance_count}"
  k8s_master_disk_size       = "${var.k8s_master_disk_size}"
  etcd_endpoint              = "${module.etcd_cluster.etcd_endpoint}"
  k8s_master_endpoint        = "${module.etcd_cluster.k8s_master_endpoint}"
  sg_vpn_id                  = "${module.foundations.sg_vpn_id}"
  k8s_master_iam_role_name   = "${module.foundations.k8s_master_iam_role_name}"
  k8s_master_iam_profile_arn = "${module.foundations.k8s_master_profile_arn}"
  route53_internal_zone_id   = "${module.foundations.route53_internal_zone_id}"
  bastion_ip                 = "${module.foundations.bastion_ip}"
  bastion_ssh_port           = "${var.bastion_ssh_port}"
  terraform_ssh_key_path     = "${var.terraform_ssh_key_path}"
  cloud_config_bucket        = "${module.foundations.cloud_config_bucket}"
  private_subnet_ids         = "${module.foundations.private_subnet_ids}"
  internal_domain            = "${var.internal_domain}"
  usernames                  = ["${var.usernames}"]
  userkeys                   = ["${var.userkeys}"]

  # TLS assets
  k8s_tls_cakey   = "${var.k8s_tls_cakey}"
  k8s_tls_cacert  = "${var.k8s_tls_cacert}"
  k8s_tls_apikey  = "${var.k8s_tls_apikey}"
  k8s_tls_apicert = "${var.k8s_tls_apicert}"

  dependency_hooks = "${module.etcd_cluster.dependency_hook}"
}
