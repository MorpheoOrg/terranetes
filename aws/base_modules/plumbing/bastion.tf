/*
 * Bastion host that exists from cluster bootstrap and that can enable SSH
 * connection to any node in the cluster for authorized peers.
 *
 * NAT host that allows instances in private subnets to connect to the
 * to the Internet (to download Docker images, updates...)
 *
 * TODO FIXME: this is not optimal since it uses SSH Agent forwarding.
 * We should use a VPN connection instead. However, I'm a bit reluctant to
 * adding more dependencies on pure AWS components and AWS VPN connections
 * aren't really cheap.
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

resource "aws_instance" "bastion" {
  ami                                  = "${data.aws_ami.coreos_stable.id}"
  instance_type                        = "t2.micro"
  monitoring                           = false
  tenancy                              = "default"
  instance_initiated_shutdown_behavior = "stop"

  subnet_id              = "${element(aws_subnet.public.*.id, 0)}"
  source_dest_check      = true
  vpc_security_group_ids = ["${aws_security_group.vpn.id}", "${aws_security_group.trusted_ips.id}"]

  iam_instance_profile = "${aws_iam_instance_profile.bastion.id}"

  tags {
    Name         = "bastion"
    cluster-name = "${var.cluster_name}"
  }

  user_data = "${data.template_file.bastion_s3_cloud_config.rendered}"
}
