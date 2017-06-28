/*
 * Creates an S3 bucket on which we'll upload the cloud configuration of our
 * different instances so that it can later be retrieved by systemd when they
 * boot. We had to use S3 in order to pass through the 16KB limit imposed by
 * AWS on the user-config text that can be passed to instances (our SSH public
 * keys weigh more than that when we add them up.
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

resource "aws_s3_bucket_object" "k8s_master_cloud_config" {
  bucket = "${var.cloud_config_bucket}"
  key    = "${var.cluster_name}/k8s_master.yml"

  content = <<EOF
#cloud-config

coreos:
${data.template_file.flannel.rendered}
  units:
${data.template_file.flannel_units.rendered}
${data.template_file.kubelet_master_units.rendered}
${join("\n", var.extra_units)}
write_files:
${data.template_file.k8s_master_files.rendered}
${join("\n", var.extra_files)}
users:
${join("\n", data.template_file.user.*.rendered)}
EOF
}
