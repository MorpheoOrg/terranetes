/*
 * Load balancer and public Kubernetes workers on which our Ingress controllers
 * will live and listen.
 */

# Network rules on the load balancer
resource "aws_security_group" "web_access" {
  count = "${length(var.flavors["ingress"]) == 1 ? 0 : 1}"

  name        = "https"
  description = "[Managed by Terraform] Opens up ports 443 and 80 for everyone. Rules apply to our intake load-balancer"
  vpc_id      = "${module.k8s_head.vpc_id}"

  # HTTPs
  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    KubernetesCluster = "${var.cluster_name}"
  }
}

resource "aws_security_group" "openvpn_access" {
  count = "${length(matchkeys(list("vpn"), list("vpn"), split(",", element(var.flavors["ingress"], 2))))}"

  name        = "openvpn"
  description = "[Managed by Terraform] Opens up the chosen OpenVPN port. Rules apply to our intake load-balancer"
  vpc_id      = "${module.k8s_head.vpc_id}"

  # Used for OpenVPN
  ingress {
    protocol    = "tcp"
    from_port   = "${var.vpn_port}"
    to_port     = "${var.vpn_port}"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    KubernetesCluster = "${var.cluster_name}"
  }
}

#
# Frontend TCP load-balancer, all public traffic goes through it straight to
# load-balancing nodes
resource "aws_elb" "intake_elb" {
  count = "${length(var.flavors["ingress"]) == 1 ? 0 : 1}"

  cross_zone_load_balancing = true
  name                      = "front-elb-${var.cluster_name}"
  security_groups           = ["${concat(list("${module.k8s_head.sg_vpn_id}", "${aws_security_group.web_access.id}"), aws_security_group.openvpn_access.*.id)}"]
  subnets                   = ["${module.k8s_head.public_subnet_ids}"]
  internal                  = false

  listener {
    instance_port     = 443
    instance_protocol = "tcp"
    lb_port           = 443
    lb_protocol       = "tcp"
  }

  listener {
    instance_port     = 80
    instance_protocol = "tcp"
    lb_port           = 80
    lb_protocol       = "tcp"
  }

  listener {
    instance_port     = "${var.vpn_port}"
    instance_protocol = "tcp"
    lb_port           = "${var.vpn_port}"
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    target              = "TCP:80"
    interval            = 10
  }

  idle_timeout = 60
}

// Since NGinX supports it, let's enable proxy protocol
resource "aws_proxy_protocol_policy" "web_ports" {
  count = "${length(var.flavors["ingress"]) == 1 ? 0 : 1}"

  load_balancer  = "${aws_elb.intake_elb.name}"
  instance_ports = ["80", "443"]
}

// System nodes for kube-dns, the dashboard, cluster autoscaler etc.
module "ingress_nodes" {
  source = "../../base_modules/k8s_worker_cluster"

  enable = "${length(var.flavors["ingress"]) == 1 ? 0 : 1}"

  # Attach instances to our intake ELB
  load_balancers = ["${aws_elb.intake_elb.name}"]

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
  worker_group_name  = "ingress"
  coreos_ami_id      = "${module.k8s_head.coreos_ami_id}"
  hyperkube_tag      = "${var.hyperkube_tag}"
  node_instance_type = "${var.ingress_node_instance_type}"
  min_asg_size       = "${length(var.flavors["ingress"]) == 1 ? 1 : element(var.flavors["ingress"], 0)}"
  max_asg_size       = "${length(var.flavors["ingress"]) == 1 ? 1 : element(var.flavors["ingress"], 1)}"
  k8s_node_disk_size = "${var.ingress_node_disk_size}"
  k8s_node_labels    = "role.node=ingress"

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
    "${data.template_file.nginx_ingress_controller.rendered}",
    "${data.template_file.ingress_lego.rendered}",
    "${data.template_file.vpn.rendered}",
  ]

  kubernetes_manifests_to_deploy = ["${matchkeys(list(
    "${data.template_file.nginx_ingress_controller.rendered}",
    "${data.template_file.ingress_lego.rendered}",
    "${data.template_file.vpn.rendered}",
    ), list(
      "nginx-ingress-controller",
      "lego",
      "vpn"
    ), split(",", element(var.flavors["ingress"], 2)) )}"]

  # Users with SSH access to our instances and their keys
  usernames   = ["${var.usernames}"]
  userkeys    = ["${var.userkeys}"]
  extra_units = ["${var.ingress_node_extra_units}"]
  extra_files = ["${var.ingress_node_extra_files}"]

  # Necessary during bootstrap, flannel needs etcd to configure the network overlay
  dependency_hooks = "${module.k8s_head.dependency_hook}"
}

data "template_file" "nginx_ingress_controller" {
  template = "${file("${path.module}/../../../k8s_manifests/ingress/nginx-ingress-controller.yml")}"

  vars {
    extra_tcp_config         = "${join("\n", data.template_file.ingress_extra_tcp_config.*.rendered)}"
    replicas                 = "${var.ingress_controller_replicas}"
    ingress_controller_image = "${var.ingress_controller_image}"
    extra_tcp_ports          = "${join("\n", data.template_file.ingress_extra_tcp_ports.*.rendered)}"
    default_backend_image    = "${var.ingress_default_backend_image}"
  }
}

data "template_file" "ingress_extra_tcp_config" {
  count = "${length(matchkeys(list("vpn"), list("vpn"), split(",", element(var.flavors["ingress"], 2))))}"

  template = "${file("${path.module}/resources/ingress_extra_tcp_config.yml")}"

  vars {
    ingress_port = "${var.vpn_port}"
    service_port = "${var.vpn_port}"
    namespace    = "ingress"
    service      = "openvpn"
  }
}

data "template_file" "ingress_extra_tcp_ports" {
  count = "${length(matchkeys(list("vpn"), list("vpn"), split(",", element(var.flavors["ingress"], 2))))}"

  template = "${file("${path.module}/resources/ingress_extra_tcp_ports.yml")}"

  vars {
    name = "openvpn"
    port = "${var.vpn_port}"
  }
}

data "template_file" "ingress_lego" {
  template = "${file("${path.module}/../../../k8s_manifests/ingress/lego.yml")}"

  vars {
    lego_image = "${var.lego_image}"
    lego_email = "${var.lego_email}"
    acme_url   = "${var.acme_url}"
  }
}

data "template_file" "vpn" {
  template = "${file("${path.module}/../../../k8s_manifests/ingress/openvpn.yml")}"

  vars {
    image        = "${var.openvpn_image}"
    port         = "${var.vpn_port}"
    vpn_endpoint = "${aws_elb.intake_elb.dns_name}"
    vpn_network  = "${var.vpn_network}"
    vpn_subnet   = "${var.vpn_subnet}"
    pod_network  = "10.${var.vpc_number+1}.0.0"
    pod_subnet   = "255.255.0.0"
  }
}
