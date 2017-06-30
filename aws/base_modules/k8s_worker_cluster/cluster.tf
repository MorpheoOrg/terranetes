/*
 * Spawns a pool of private kubernetes API workers. These are well suited to
 * services running API services (and possibly other types of similar backend
 * services that are supposed to run simple web servers).
 *
 * CPU intensive services whose purpose is to run time & resource consuming
 * services should rather be held by the "kubernetes-computation-worker" nodes.
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

resource "aws_autoscaling_group" "k8s_worker_group" {
  count = "${var.enable}"

  name                 = "${var.cluster_name}-${var.worker_group_name}"
  vpc_zone_identifier  = ["${var.private_subnet_ids}"]
  launch_configuration = "${aws_launch_configuration.k8s_worker.name}"

  load_balancers = ["${var.load_balancers}"]

  max_size = "${var.max_asg_size}"
  min_size = "${var.min_asg_size}"

  termination_policies = ["OldestLaunchConfiguration", "ClosestToNextInstanceHour"]
  force_delete         = true

  tag {
    key                 = "Name"
    value               = "${var.worker_group_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "KubernetesCluster"
    value               = "${var.cluster_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "cluster-name"
    value               = "${var.cluster_name}"
    propagate_at_launch = "true"
  }

  tag {
    key                 = "TerraformDependencyHook"
    value               = "${var.dependency_hooks}"
    propagate_at_launch = false
  }

  # This one spawns the kube-system base components (kube-dns, heapster,
  # kubernetes-dashboard) as well as optional addons (nginx ingress controller,
  # lego for automatic SSL with Let's Encrypt, OpenVPN...)
  provisioner "local-exec" {
    command = <<EOF
      ${path.module}/scripts/apply_manifests.sh \
      "${path.module}/../k8s_master_cluster/scripts/k8s_con.sh" \
      ${var.bastion_ssh_port} ${var.terraform_ssh_key_path} \
      ${var.cluster_name} ${var.internal_domain} bastion ${var.vpc_region} \
      ${join(" ", formatlist("\"%s\"", var.kubernetes_manifests_to_deploy))}
EOF
  }

  # And this one destroys the given resources from the Kubernetes API when the
  # nodes are destroyed
  provisioner "local-exec" {
    when = "destroy"

    command = <<EOF
      ${path.module}/scripts/delete_manifests.sh \
      "${path.module}/../k8s_master_cluster/scripts/k8s_con.sh" \
      ${var.bastion_ssh_port} ${var.terraform_ssh_key_path} \
      ${var.cluster_name} ${var.internal_domain} bastion ${var.vpc_region} \
      ${join(" ", formatlist("\"%s\"", var.all_kubernetes_manifests))}
EOF
  }
}

resource "aws_launch_configuration" "k8s_worker" {
  count = "${var.enable}"

  name_prefix   = "${var.cluster_name}-${var.worker_group_name}-"
  image_id      = "${var.coreos_ami_id}"
  instance_type = "${var.node_instance_type}"

  security_groups             = ["${var.sg_ids}"]
  associate_public_ip_address = false
  iam_instance_profile        = "${var.k8s_worker_profile_arn}"

  lifecycle {
    create_before_destroy = true
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "${var.k8s_node_disk_size}"
    delete_on_termination = true
  }

  enable_monitoring = true

  placement_tenancy = "default"

  user_data = "${data.template_file.k8s_worker_s3_cloud_config.rendered}"
}
