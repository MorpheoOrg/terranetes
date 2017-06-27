/*
 *  Maintainer: Étienne Lafarge <etienne@rythm.co>
 *   Copyright (C) 2017 Morpheo Org - Rythm SAS
 *
 *  see https://github.com/MorpheoOrg/terranetes/COPYRIGHT
 *  and https://github.com/MorpheoOrg/terranetes/LICENSE
 *  for more information.
 */

resource "aws_s3_bucket" "cloud_config" {
  bucket        = "${var.cloud_config_bucket}"
  acl           = "private"
  force_destroy = true
}

resource "aws_s3_bucket_object" "bastion_cloud_config" {
  bucket = "${aws_s3_bucket.cloud_config.bucket}"
  key    = "${var.cluster_name}/bastion.yml"

  content = <<EOF
#cloud-config

coreos:
  units:
    - name: sshd.socket
      command: restart
      runtime: true
      content: |
        [Socket]
        ListenStream=${var.bastion_ssh_port}
        FreeBind=true
        Accept=yes
${join("\n", var.bastion_extra_units)}

write_files:
  - path: /etc/ssh/sshd_config
    permissions: 0600
    owner: root:root
    content: |
      UsePrivilegeSeparation sandbox
      Subsystem sftp internal-sftp
      ClientAliveInterval 180
      UseDNS no
      UsePAM yes
      PrintMotd no
      LogLevel DEBUG
      PermitRootLogin no

users:
${join("\n", data.template_file.user.*.rendered)}
EOF
}
