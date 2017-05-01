/*
 * Spawns a kubernetes multi-node master cluster on top of flannel for
 * an abstraction of container networking at cloud scale.
 *
 * Pods all live in the 10.{vpc_number + 1}.0.0/16 CIDR, no matter what subnet
 * they're living. It simplifies things a lot.
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

resource "aws_elb" "k8s_master" {
  cross_zone_load_balancing = true
  name                      = "k8s-master-${var.cluster_name}"
  security_groups           = ["${var.sg_vpn_id}"]
  subnets                   = ["${var.private_subnet_ids}"]
  internal                  = true

  listener {
    instance_port     = 443
    instance_protocol = "tcp"
    lb_port           = 443
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5

    target   = "HTTP:8080/healthz"
    interval = 10
  }

  idle_timeout = 3600
}

resource "aws_autoscaling_group" "k8s_masters" {
  name                 = "k8s-masters-${var.cluster_name}"
  vpc_zone_identifier  = ["${var.private_subnet_ids}"]
  launch_configuration = "${aws_launch_configuration.k8s_master.name}"

  load_balancers = ["${aws_elb.k8s_master.name}"]

  max_size = "${2 * var.k8s_master_instance_count}"
  min_size = "${var.k8s_master_instance_count}"

  health_check_type         = "${var.k8s_master_asg_health_check_type}"
  health_check_grace_period = "1200"
  default_cooldown          = "30"

  termination_policies = ["OldestLaunchConfiguration", "ClosestToNextInstanceHour"]
  force_delete         = true

  tag {
    key                 = "Name"
    value               = "kubernetes-master"
    propagate_at_launch = true
  }

  tag {
    key                 = "KubernetesCluster"
    value               = "${var.cluster_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "TerraformDependencyHook"
    value               = "${var.dependency_hooks}"
    propagate_at_launch = false
  }

  tag {
    key                 = "cluster-name"
    value               = "${var.cluster_name}"
    propagate_at_launch = "true"
  }
}

resource "aws_launch_configuration" "k8s_master" {
  name_prefix   = "k8s-master-${var.cluster_name}-"
  image_id      = "${var.coreos_ami_id}"
  instance_type = "${var.k8s_master_instance_type}"

  security_groups             = ["${var.sg_vpn_id}"]
  iam_instance_profile        = "${var.k8s_master_iam_profile_arn}"
  associate_public_ip_address = false

  lifecycle {
    create_before_destroy = true
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "${var.k8s_master_disk_size}"
    delete_on_termination = true
  }

  enable_monitoring = true

  placement_tenancy = "default"

  user_data = "${data.template_file.k8s_master_s3_cloud_config.rendered}"
}

# Route53 configuration for the ELB associated with the internal DNS
resource "aws_route53_record" "k8s_master_internal" {
  zone_id = "${var.route53_internal_zone_id}"
  name    = "${var.k8s_master_endpoint}"
  type    = "CNAME"
  ttl     = "5"
  records = ["${aws_elb.k8s_master.dns_name}"]
}

# A hook we can use to make sure all the cluster's components are up from other
# pieces of Terraform code.
resource "null_resource" "dependency_hook" {
  depends_on = ["aws_route53_record.k8s_master_internal", "aws_autoscaling_group.k8s_masters"]
}
