/*
 * Describes an etcd3 cluster running on top of CoreOS, auto discovering itself,
 * in an EC2 auto-scaling group "in case configuration shit hits the fan" but it
 * shouldn't be the case. The auto-scaling group is mostly here to provide
 * multi-AZ redundancy out-of-the-box.
 *
 * TODO: remove the ELB and rather use the AWS golang API in a rkt-embedded
 * binary to fetch ETCD IPs from the ASG configuration and create the systemd
 * drop ins containing these IPs using that binary.
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

resource "aws_elb" "etcd" {
  cross_zone_load_balancing = true
  name                      = "etcd-${var.cluster_name}"
  security_groups           = ["${var.sg_vpn_id}"]
  subnets                   = ["${var.private_subnet_ids}"]
  internal                  = true

  listener {
    instance_port     = 2379
    instance_protocol = "tcp"
    lb_port           = 2379
    lb_protocol       = "tcp"
  }

  listener {
    instance_port     = 2380
    instance_protocol = "tcp"
    lb_port           = 2380
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 4
    target              = "HTTP:2379/v2/keys/${var.etcd_health_key}"
    interval            = 5
  }

  idle_timeout = 60
}

resource "aws_autoscaling_group" "etcd" {
  name = "etcd-${var.cluster_name}"

  vpc_zone_identifier  = ["${var.private_subnet_ids}"]
  launch_configuration = "${aws_launch_configuration.etcd.name}"

  load_balancers = ["${aws_elb.etcd.name}"]

  max_size = "${var.etcd_instance_count + 1}"
  min_size = "${var.etcd_instance_count}"

  health_check_type         = "${var.etcd_asg_health_check_type}"
  health_check_grace_period = "600"

  termination_policies = ["OldestLaunchConfiguration", "ClosestToNextInstanceHour"]
  force_delete         = true

  tag {
    key                 = "Name"
    value               = "etcd"
    propagate_at_launch = true
  }

  tag {
    key                 = "cluster-name"
    value               = "${var.cluster_name}"
    propagate_at_launch = "true"
  }

  provisioner "local-exec" {
    command = "${path.module}/resources/bootstrap_etcd_cluster.sh ${var.vpc_region} ${var.terraform_ssh_key_path} ${var.bastion_ip} ${var.bastion_ssh_port} ${self.name} ${self.min_size} ${path.module} http://${aws_route53_record.etcd_internal.name}:2379 ${var.etcd_health_key}"
  }
}

resource "aws_launch_configuration" "etcd" {
  name_prefix   = "etcd-${var.cluster_name}-"
  image_id      = "${var.coreos_ami_id}"
  instance_type = "${var.etcd_instance_type}"

  security_groups             = ["${var.sg_vpn_id}"]
  iam_instance_profile        = "${var.etcd_iam_profile_arn}"
  associate_public_ip_address = false

  lifecycle {
    create_before_destroy = true
  }

  root_block_device {
    volume_type = "gp2"

    volume_size           = 8
    delete_on_termination = true
  }

  enable_monitoring = true

  placement_tenancy = "default"

  user_data = "${data.template_file.etcd_s3_cloud_config.rendered}"
}

# Route53 configuration for the ELB associated with the internal DNS
resource "aws_route53_record" "etcd_internal" {
  zone_id = "${var.route53_internal_zone_id}"
  name    = "etcd.${var.cluster_name}.${var.internal_domain}"
  type    = "CNAME"
  ttl     = "5"
  records = ["${aws_elb.etcd.dns_name}"]
}

# A hook we can use to make sure all the cluster's components are up from other
# pieces of Terraform code, in our case, all non etcd-nodes & the bastion host
# need to have etcd available to correctly setup the flannel network overlay.
resource "null_resource" "dependency_hook" {
  depends_on = ["aws_route53_record.etcd_internal", "aws_autoscaling_group.etcd"]
}
