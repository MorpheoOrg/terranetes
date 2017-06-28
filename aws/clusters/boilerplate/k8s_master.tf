/*
 *  Maintainer: Étienne Lafarge <etienne@rythm.co>
 *   Copyright (C) 2017 Morpheo Org - Rythm SAS
 *
 *  see https://github.com/MorpheoOrg/terranetes/COPYRIGHT
 *  and https://github.com/MorpheoOrg/terranetes/LICENSE
 *  for more information.
 */

# Our Kubernetes master cluster and their associated etcd cluster
module "k8s_head" {
  source = "../head/"

  # Generic configuration for the cluster
  vpc_name               = "${var.vpc_name}"
  vpc_number             = "${var.vpc_number}"
  vpc_region             = "${var.vpc_region}"
  cloud_config_bucket    = "${var.cloud_config_bucket}"
  bastion_ssh_port       = "${var.bastion_ssh_port}"
  terraform_ssh_key_path = "${var.terraform_ssh_key_path}"
  internal_domain        = "${var.internal_domain}"
  cluster_name           = "${var.cluster_name}"

  trusted_cidrs = ["${var.trusted_cidrs}"]

  # Change that to use a different CoreOS version / follow the alpha/beta channel
  coreos_ami_owner_id = "${var.coreos_ami_owner_id}"
  coreos_ami_pattern  = "${var.coreos_ami_pattern}"
  virtualization_type = "${var.virtualization_type}" // Or pv for paravirtual

  # Etcd cluster configuration
  etcd_version                       = "${var.etcd_version}"
  etcd_instance_count                = "${var.etcd_instance_count}"
  etcd_instance_type                 = "${var.etcd_instance_type}"
  etcd_disk_size                     = "${var.etcd_disk_size}"
  etcd_asg_health_check_type         = "${var.etcd_asg_health_check_type}"
  etcd_asg_health_check_grace_period = "${var.etcd_asg_health_check_grace_period}"

  # Kubernetes master cluster configuration
  hyperkube_tag                            = "${var.hyperkube_tag}"
  k8s_master_instance_count                = "${var.k8s_master_instance_count}"
  k8s_master_instance_type                 = "${var.k8s_master_instance_type}"
  k8s_master_disk_size                     = "${var.k8s_master_disk_size}"
  k8s_master_asg_health_check_type         = "${var.k8s_master_asg_health_check_type}"
  k8s_master_asg_health_check_grace_period = "${var.k8s_master_asg_health_check_grace_period}"

  #  TLS assets
  k8s_tls_cakey   = "${file("./tls/${var.cluster_name}/ca.indented.key")}"
  k8s_tls_cacert  = "${file("./tls/${var.cluster_name}/ca.indented.pem")}"
  k8s_tls_apikey  = "${file("./tls/${var.cluster_name}/apiserver.indented.key")}"
  k8s_tls_apicert = "${file("./tls/${var.cluster_name}/apiserver.indented.pem")}"

  # Users with SSH access to our instances and their keys
  usernames = ["${var.usernames}"]
  userkeys  = ["${var.userkeys}"]

  bastion_extra_units = ["${var.bastion_extra_units}"]
  bastion_extra_files = ["${var.bastion_extra_files}"]

  # TODO: force backups and add backup bucket and key prefix variables
  etcd_extra_units = ["${var.etcd_extra_units}"]
  etcd_extra_files = ["${var.etcd_extra_files}"]

  k8s_master_extra_units = ["${var.k8s_master_extra_units}"]
  k8s_master_extra_files = ["${var.k8s_master_extra_files}"]
}
