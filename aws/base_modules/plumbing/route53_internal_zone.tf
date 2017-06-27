/*
 * Internal DNS zones for our etcd & kubernetes cluster. (the DNS routes are
 * defined in the etcd/k8s groups).
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
resource "aws_route53_zone" "internal" {
  name       = "${var.cluster_name}.${var.internal_domain}"
  comment    = "[Terraform Kubernetes] Internal DNS route configuration for VPC ${var.cluster_name}"
  vpc_id     = "${aws_vpc.main.id}"
  vpc_region = "${var.vpc_region}"
}

resource "aws_route53_record" "internal_ns" {
  zone_id = "${aws_route53_zone.internal.zone_id}"
  name    = "${var.cluster_name}.${var.internal_domain}"
  type    = "NS"
  ttl     = "5"

  records = [
    "${aws_route53_zone.internal.name_servers.0}",
    "${aws_route53_zone.internal.name_servers.1}",
    "${aws_route53_zone.internal.name_servers.2}",
    "${aws_route53_zone.internal.name_servers.3}",
  ]
}
