/*
 *  Security group configuration for our main VPC.
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

/*
 * IP filtering for SSH access as well as access to all the ports dedicated to the remote administration of our
 * Kubernetes cluster. This traffic flow through our bastion host.
 */
resource "aws_security_group" "trusted_ips" {
  name        = "trusted-ips"
  description = "[Managed by Terraform] Allows SSH for trusted IPs (ours + the Paris office) for bastion hosts."
  vpc_id      = "${aws_vpc.main.id}"

  # SSH
  ingress {
    protocol  = "tcp"
    from_port = "${var.bastion_ssh_port}"
    to_port   = "${var.bastion_ssh_port}"

    #
    # List of IPs (CIDRs actually) allowed to SSH onto our bastion
    #
    cidr_blocks = ["${var.trusted_cidrs}"]
  }
}

# Allow our instances to fetch things on the Internet
resource "aws_security_group" "vpn" {
  name        = "vpn"
  description = "[Managed by Terraform] Opens outbound connections to 0.0.0.0/0 and allow inbound connections from other machines or load-balancers inside our VPN."
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    protocol  = "tcp"
    from_port = 0
    to_port   = 65535

    # TODO: replace that with a list of CIDR blocks matching all our existing
    # VPCs and other networks we'd like to join, taken as a variable.
    cidr_blocks = ["${aws_vpc.main.cidr_block}"]
  }

  ingress {
    protocol  = "udp"
    from_port = 0
    to_port   = 65535

    # TODO: replace that with a list of CIDR blocks matching all our existing
    # VPCs and other networks we'd like to join, taken as a variable.
    cidr_blocks = ["${aws_vpc.main.cidr_block}", "10.${var.vpc_number + 1}.0.0/16"]
  }

  egress {
    protocol    = "tcp"
    from_port   = 0
    to_port     = 65535
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "udp"
    from_port   = 0
    to_port     = 65535
    cidr_blocks = ["0.0.0.0/0"]
  }

  # TODO: we need this for Kubernetes rules not to be deleted... but actually, we should figure out a way to have
  # Kubernetes put its rules in another group that will ignore changes.
  lifecycle {
    ignore_changes = ["ingress"]
  }
}
