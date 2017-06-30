// System nodes for kube-dns, the dashboard, cluster autoscaler etc.
module "k8s_system_nodes" {
  source = "../../base_modules/k8s_worker_cluster"

  enable = "${length(var.flavors["system"]) == 1 ? 0 : 1}"

  # Generic configuration
  vpc_name               = "${var.vpc_name}"
  vpc_number             = "${var.vpc_number}"
  vpc_region             = "${var.vpc_region}"
  cloud_config_bucket    = "${var.cloud_config_bucket}"
  bastion_ssh_port       = "${var.bastion_ssh_port}"
  terraform_ssh_key_path = "${var.terraform_ssh_key_path}"
  internal_domain        = "${var.internal_domain}"
  cluster_name           = "${var.cluster_name}"

  # Worker cluster configuration
  worker_group_name  = "system"
  coreos_ami_id      = "${module.k8s_head.coreos_ami_id}"
  hyperkube_tag      = "${var.hyperkube_tag}"
  node_instance_type = "${var.system_node_instance_type}"
  min_asg_size       = "${length(var.flavors["system"]) == 1 ? 1 : element(var.flavors["system"], 0)}"
  max_asg_size       = "${length(var.flavors["system"]) == 1 ? 1 : element(var.flavors["system"], 1)}"
  k8s_node_disk_size = "${var.system_node_disk_size}"
  k8s_node_labels    = "role.node=system"

  k8s_master_endpoint = "${module.k8s_head.k8s_master_endpoint}"
  etcd_endpoint       = "${module.k8s_head.etcd_endpoint}"
  private_subnet_ids  = "${module.k8s_head.private_subnet_ids}"
  sg_ids              = ["${module.k8s_head.sg_vpn_id}"]

  k8s_worker_iam_role_name = "${module.k8s_head.k8s_worker_iam_role_name}"
  k8s_worker_profile_arn   = "${module.k8s_head.k8s_worker_profile_arn}"

  # TLS assets
  k8s_tls_cakey  = "${file("./tls/${var.cluster_name}/ca.indented.key")}"
  k8s_tls_cacert = "${file("./tls/${var.cluster_name}/ca.indented.pem")}"

  # Manifests for resources deployed on this node
  all_kubernetes_manifests = [
    "${data.template_file.cluster_autoscaler.rendered}",
    "${data.template_file.kube_dns.rendered}",
    "${data.template_file.kube_dns_autoscaler.rendered}",
    "${data.template_file.kube_dashboard.rendered}",
    "${data.template_file.heapster.rendered}",
    "${data.template_file.node_problem_detector.rendered}",
    "${data.template_file.rescheduler.rendered}",
  ]

  kubernetes_manifests_to_deploy = ["${matchkeys(
    list(
      "${data.template_file.cluster_autoscaler.rendered}",
      "${data.template_file.kube_dns.rendered}",
      "${data.template_file.kube_dns_autoscaler.rendered}",
      "${data.template_file.kube_dashboard.rendered}",
      "${data.template_file.heapster.rendered}",
      "${data.template_file.node_problem_detector.rendered}",
      "${data.template_file.rescheduler.rendered}"
    ), list(
      "cluster_autoscaler",
      "dns",
      "dns_autoscaler",
      "dashboard",
      "heapster",
      "node_problem_detector",
      "rescheduler"
    ), split(",", element(var.flavors["system"], 2)) )}"]

  # Users with SSH access to our instances and their keys
  usernames   = ["${var.usernames}"]
  userkeys    = ["${var.userkeys}"]
  extra_units = ["${var.system_node_extra_units}"]
  extra_files = ["${var.system_node_extra_files}"]

  # Necessary during bootstrap, flannel needs etcd to configure the network overlay
  dependency_hooks = "${module.k8s_head.dependency_hook}"
}

data "template_file" "cluster_autoscaler" {
  template = "${file("${path.module}/../../../k8s_manifests/system/cluster-autoscaler.yml")}"

  vars {
    cluster_autoscaler_image = "${var.cluster_autoscaler_image}"
    aws_region               = "${var.vpc_region}"

    per_asg_configuration = <<EOF
${join("\n", data.template_file.cluster_autoscaler_asg_line.*.rendered)}
EOF
  }
}

data "template_file" "cluster_autoscaler_asg_line" {
  count = "${length(keys(var.flavors))}"

  template = "${file("${path.module}/resources/cluster_autoscaler_asg_line.yml")}"

  vars {
    min_size = "${element(var.flavors["${element(keys(var.flavors), count.index)}"], 0)}"
    max_size = "${element(var.flavors["${element(keys(var.flavors), count.index)}"], 1)}"
    asg_name = "${var.cluster_name}-${element(keys(var.flavors), count.index)}"
  }
}

data "template_file" "kube_dns" {
  template = "${file("${path.module}/../../../k8s_manifests/system/dns.yml")}"

  vars {
    replicas              = "${var.kube_dns_replicas}"
    kubedns_image         = "${var.kube_dns_image}"
    dnsmasq_image         = "${var.kube_dns_dnsmasq_image}"
    dnsmasq_metrics_image = "${var.kube_dns_dnsmasq_metrics_image}"
    exechealthz_image     = "${var.kube_dns_exechealthz_image}"
    cluster_name          = "${var.cluster_name}"
    kubedns_ip            = "10.${var.vpc_number + 1}.128.53"
  }
}

data "template_file" "kube_dns_autoscaler" {
  template = "${file("${path.module}/../../../k8s_manifests/system/dns-autoscaler.yml")}"

  vars {
    cluster_proportional_autoscaler_image = "${var.cluster_proportional_autoscaler_image}"
  }
}

data "template_file" "kube_dashboard" {
  template = "${file("${path.module}/../../../k8s_manifests/system/dashboard.yml")}"

  vars {
    kubedashboard_image = "${var.kube_dashboard_image}"
  }
}

data "template_file" "heapster" {
  template = "${file("${path.module}/../../../k8s_manifests/system/heapster.yml")}"

  vars {
    heapster_image      = "${var.heapster_image}"
    addon_resizer_image = "${var.addon_resizer_image}"
  }
}

data "template_file" "node_problem_detector" {
  template = "${file("${path.module}/../../../k8s_manifests/system/node-problem-detector.yml")}"

  vars {
    node_problem_detector_image = "${var.node_problem_detector_image}"
  }
}

data "template_file" "rescheduler" {
  template = "${file("${path.module}/../../../k8s_manifests/system/rescheduler.yml")}"

  vars {
    rescheduler_image = "${var.rescheduler_image}"
  }
}
