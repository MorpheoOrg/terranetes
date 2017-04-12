/*
 *  Maintainer: Étienne Lafarge <etienne@rythm.co>
 *   Copyright (C) 2017 Morpheo Org - Rythm SAS
 *
 *  see https://github.com/MorpheoOrg/terranetes/COPYRIGHT
 *  and https://github.com/MorpheoOrg/terranetes/LICENSE
 *  for more information.
 */

##### CLOUD CONFIG TO DOWNLOAD MORE CLOUD CONFIG FROM S3 (0_o) ######
data "template_file" "etcd_s3_cloud_config" {
  template = "${file("${path.module}/../cloud-configs/run_s3_cloud_config.yml")}"

  vars {
    bucket_region         = "${var.vpc_region}"
    bucket                = "${var.cloud_config_bucket}"
    key                   = "${aws_s3_bucket_object.etcd_cloud_config.key}"
    iam_cloud_config_role = "${var.etcd_iam_role_name}"
  }
}

##### ETCD'S CLOUD CONFIG #####
data "template_file" "etcd_config" {
  template = "${file("${path.module}/resources/etcd_config.yml")}"

  vars {
    etcd_version = "${var.etcd_version}"
  }
}

data "template_file" "etcd_unit" {
  template = "${file("${path.module}/resources/etcd_unit.yml")}"
}

data "template_file" "etcd_scripts" {
  template = "${file("${path.module}/resources/etcd_scripts.yml")}"

  vars {
    cleanup_etcd_cluster_script     = "${file("${path.module}/resources/cleanup_etcd_cluster.sh")}"
    reconfigure_etcd_cluster_script = "${file("${path.module}/resources/reconfigure_etcd_cluster.sh")}"
  }
}

data "template_file" "etcd_reconfiguration_unit" {
  template = "${file("${path.module}/resources/etcd_reconfiguration_unit.yml")}"

  vars {
    etcd_version  = "${var.etcd_version}"
    etcd_endpoint = "http://${aws_route53_record.etcd_internal.name}:2379"
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
