/*
 *  Maintainer: Étienne Lafarge <etienne@rythm.co>
 *   Copyright (C) 2017 Morpheo Org - Rythm SAS
 *
 *  see https://github.com/MorpheoOrg/terranetes/COPYRIGHT
 *  and https://github.com/MorpheoOrg/terranetes/LICENSE
 *  for more information.
 */

data "template_file" "k8s_worker_s3_cloud_config" {
  template = "${file("${path.module}/../cloud-configs/run_s3_cloud_config.yml")}"

  vars {
    bucket_region         = "${var.vpc_region}"
    bucket                = "${var.cloud_config_bucket}"
    key                   = "${aws_s3_bucket_object.k8s_public_workers_cloud_configs.key}"
    iam_cloud_config_role = "${var.k8s_worker_iam_role_name}"
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

##### KUBERNETES WORKERS CONFIGURATION #####
data "template_file" "kubelet_public_worker_units" {
  template = "${file("${path.module}/resources/kubelet_worker_units.yml")}"

  vars {
    master_endpoint    = "https://${var.k8s_master_endpoint}"
    etcd_endpoint      = "${var.etcd_endpoint}"
    k8s_network_prefix = "${var.vpc_number + 1}"
    k8s_service_dns_ip = "10.${var.vpc_number + 1}.128.53"
    hyperkube_tag      = "${var.hyperkube_tag}"
    cluster_name       = "${var.cluster_name}"
    node_labels        = "${var.k8s_node_labels}"
  }
}

data "template_file" "k8s_worker_files" {
  template = "${file("${path.module}/resources/k8s_worker_files.yml")}"

  vars {
    hyperkube_tag   = "${var.hyperkube_tag}"
    master_endpoint = "https://${var.k8s_master_endpoint}"
    cluster_name    = "${var.cluster_name}"

    k8s_tls_cakey  = "${var.k8s_tls_cakey}"
    k8s_tls_cacert = "${var.k8s_tls_cacert}"

    generate_tls_assets_for_worker_script = "${file("${path.module}/../scripts/generate_tls_assets_for_worker.sh")}"
  }
}

data "template_file" "user" {
  count    = "${length(var.usernames)}"
  template = "${file("${path.module}/../cloud-configs/user_cloud_config.yml")}"

  vars {
    username    = "${element(var.usernames, count.index)}"
    public_keys = "      - ${join("\n      - ", split(",", element(var.userkeys, count.index)))}"
  }
}
