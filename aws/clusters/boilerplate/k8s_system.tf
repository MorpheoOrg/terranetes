// System nodes for kube-dns, the dashboard, cluster autoscaler etc.
module "k8s_system_nodes" {
  source = "../../base_modules/k8s_worker_cluster"

  enable = "${lookup(var.flavors, "system")}"

  # Generic configuration
  vpc_name               = "${var.vpc_name}"
  vpc_number             = "${var.vpc_number}"
  vpc_region             = "${var.vpc_region}"
  cloud_config_bucket    = "${var.cloud_config_bucket}"
  bastion_ip             = "${module.k8s_head.bastion_ip}"
  bastion_ssh_port       = "${var.bastion_ssh_port}"
  terraform_ssh_key_path = "${var.terraform_ssh_key_path}"
  internal_domain        = "${var.internal_domain}"
  cluster_name           = "${var.cluster_name}"

  # Worker cluster configuration
  worker_group_name  = "system"
  coreos_ami_id      = "${module.k8s_head.coreos_ami_id}"
  hyperkube_tag      = "${var.hyperkube_tag}"
  node_instance_type = "${var.system_node_instance_type}"
  min_asg_size       = "${var.system_node_min_asg_size}"
  max_asg_size       = "${var.system_node_max_asg_size}"
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
  kubernetes_manifests = ["${matchkeys(list("${data.template_file.kube_dns.rendered}", "${data.template_file.kube_dashboard.rendered}"), list("dns", "dashboard"), "${var.kube_system_flavors}")}"]

  # Users with SSH access to our instances and their keys
  usernames   = ["${var.usernames}"]
  userkeys    = ["${var.userkeys}"]
  extra_units = ["${var.system_node_extra_units}"]
  extra_files = ["${var.system_node_extra_files}"]

  # Necessary during bootstrap, flannel needs etcd to configure the network overlay
  dependency_hooks = "${module.k8s_head.dependency_hook}"
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

data "template_file" "kube_dashboard" {
  template = "${file("${path.module}/../../../k8s_manifests/system/dashboard.yml")}"

  vars {
    kubedashboard_image = "${var.kube_dashboard_image}"
  }
}
