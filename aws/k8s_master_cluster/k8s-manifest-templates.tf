/*
 *  Maintainer: Étienne Lafarge <etienne@rythm.co>
 *   Copyright (C) 2017 Morpheo Org - Rythm SAS
 *
 *  see https://github.com/MorpheoOrg/terranetes/COPYRIGHT
 *  and https://github.com/MorpheoOrg/terranetes/LICENSE
 *  for more information.
 *
 * This file holds templates for all kubernetes manifests that can be used to
 * create resources on a newly spawned cluster as soon as the master is
 * available.
 */

data "template_file" "kube_dns" {
  template = "${file("${path.module}/../../k8s/system/kube-dns.yml")}"

  vars {
    replicas              = "${var.kube_dns_replicas}"
    kubedns_image         = "${var.kube_dns_image}"
    dnsmasq_image         = "${var.kube_dns_dnsmasq_image}"
    dnsmasq_metrics_image = "${var.kube_dns_dnsmasq_metrics_image}"
    exechealthz_image     = "${var.kube_dns_exechealthz_image}"
    cluster_name          = "${var.cluster_name}"
    kubedns_ip            = "10.${var.vpc_number + 1}.128.53"
  }
}

data "template_file" "kube_dashboard" {
  template = "${file("${path.module}/../../k8s/system/dashboard.yml")}"

  vars {
    kubedashboard_image = "${var.kube_dashboard_image}"
  }
}
