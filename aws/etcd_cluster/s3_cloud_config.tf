/*
 *  Maintainer: Étienne Lafarge <etienne@rythm.co>
 *   Copyright (C) 2017 Morpheo Org - Rythm SAS
 *
 *  see https://github.com/MorpheoOrg/terranetes/COPYRIGHT
 *  and https://github.com/MorpheoOrg/terranetes/LICENSE
 *  for more information.
 */

resource "aws_s3_bucket_object" "etcd_cloud_config" {
  bucket = "${var.cloud_config_bucket}"
  key    = "${var.cluster_name}/etcd.yml"

  content = <<EOF
#cloud-config

coreos:
  units:
${data.template_file.etcd_unit.rendered}
${data.template_file.etcd_reconfiguration_unit.rendered}
${join("\n", var.extra_units)}

write_files:
${data.template_file.etcd_config.rendered}
${data.template_file.etcd_scripts.rendered}
${join("\n", var.extra_files)}

users:
${join("\n", data.template_file.user.*.rendered)}
EOF
}
