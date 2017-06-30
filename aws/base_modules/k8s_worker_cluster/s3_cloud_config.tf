/*
 *  Maintainer: Étienne Lafarge <etienne@rythm.co>
 *   Copyright (C) 2017 Morpheo Org - Rythm SAS
 *
 *  see https://github.com/MorpheoOrg/terranetes/COPYRIGHT
 *  and https://github.com/MorpheoOrg/terranetes/LICENSE
 *  for more information.
 */

resource "aws_s3_bucket_object" "k8s_public_workers_cloud_configs" {
  bucket = "${var.cloud_config_bucket}"
  key    = "${var.cluster_name}/k8s_worker_${var.worker_group_name}.yml"

  content = <<EOF
#cloud-config

coreos:
${data.template_file.flannel.rendered}
  units:
${data.template_file.flannel_units.rendered}
${data.template_file.kubelet_public_worker_units.rendered}
${join("\n", var.extra_units)}
write_files:
${data.template_file.k8s_worker_files.rendered}
${join("\n", var.extra_files)}
users:
${join("\n", data.template_file.user.*.rendered)}
EOF
}
