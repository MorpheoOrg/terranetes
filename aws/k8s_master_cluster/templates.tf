/*
 * Template files (like CoreOS cloud config files or stuff like that that would
 * require information onlyt Terraform has or that is simply more convenient to
 * have in Terraform).
 *
 *  Maintainer: Étienne Lafarge <etienne@rythm.co>
 *   Copyright (C) 2017 Morpheo Org - Rythm SAS
 *
 *  see https://github.com/MorpheoOrg/terranetes/COPYRIGHT
 *  and https://github.com/MorpheoOrg/terranetes/LICENSE
 *  for more information.
 */

data "template_file" "k8s_master_s3_cloud_config" {
  template = "${file("${path.module}/../cloud-configs/run_s3_cloud_config.yml")}"

  vars {
    bucket_region         = "${var.vpc_region}"
    bucket                = "${var.cloud_config_bucket}"
    key                   = "${aws_s3_bucket_object.k8s_master_cloud_config.key}"
    iam_cloud_config_role = "${var.k8s_master_iam_role_name}"
  }
}

##### FLANNEL CONFIGURATION #####
data "template_file" "flannel" {
  template = "${file("${path.module}/../cloud-configs/flannel_config.yml")}"

  vars {
    etcd_endpoint = "${var.etcd_endpoint}"
  }
}

data "template_file" "flannel_units" {
  template = "${file("${path.module}/../cloud-configs/flannel_units.yml")}"

  vars {
    etcd_endpoint      = "${var.etcd_endpoint}"
    k8s_network_prefix = "${var.vpc_number + 1}"
  }
}

##### ETCD PROXY CONFIGURATION #####
data "template_file" "etcd_proxy_units" {
  template = "${file("${path.module}/resources/etcd_proxy_units.yml")}"

  vars {
    etcd_endpoint = "${var.etcd_endpoint}"
    etcd_version  = "${var.etcd_version}"
  }
}

data "template_file" "etcd_proxy_files" {
  template = "${file("${path.module}/resources/etcd_proxy_files.yml")}"

  vars {
    configure_etcd_proxy_script = "${file("${path.module}/resources/configure_etcd_proxy.sh")}"
  }
}

##### KUBERNETES MASTERS CONFIGURATION #####
data "template_file" "kubelet_master_units" {
  template = "${file("${path.module}/resources/kubelet_master_units.yml")}"

  vars {
    k8s_service_dns_ip = "10.${var.vpc_number + 1}.128.53"
    hyperkube_tag      = "${var.hyperkube_tag}"
    cluster_name       = "${var.cluster_name}"
    etcd_endpoint      = "${var.etcd_endpoint}"
  }
}

data "template_file" "k8s_master_files" {
  template = "${file("${path.module}/resources/k8s_master_files.yml")}"

  vars {
    hyperkube_tag    = "${var.hyperkube_tag}"
    etcd_endpoint    = "${var.etcd_endpoint}"
    k8s_service_cidr = "10.${var.vpc_number + 1}.128.0/17"
    cluster_name     = "${var.cluster_name}"
    cluster_cidr     = "10.${var.vpc_number + 1}.0.0/17"

    # TLS assets
    k8s_tls_cakey   = "${var.k8s_tls_cakey}"
    k8s_tls_cacert  = "${var.k8s_tls_cacert}"
    k8s_tls_apikey  = "${var.k8s_tls_apikey}"
    k8s_tls_apicert = "${var.k8s_tls_apicert}"
  }
}

###### USERS WITH SSH ACCESS TO OUR EC2 INSTANCES ######
data "template_file" "user" {
  count    = "${length(var.usernames)}"
  template = "${file("${path.module}/../cloud-configs/user_cloud_config.yml")}"

  vars {
    username    = "${element(var.usernames, count.index)}"
    public_keys = "      - ${join("\n      - ", split(",", element(var.userkeys, count.index)))}"
  }
}
