module "k8s_head" {
  source = ".."

  # Generic configuration for the cluster
  vpc_name               = "${var.test_vpc_name}"
  vpc_number             = "${var.test_vpc_number}"
  vpc_region             = "${var.test_vpc_region}"
  cloud_config_bucket    = "${var.test_cloud_config_bucket}"
  bastion_ssh_port       = "${var.test_bastion_ssh_port}"
  terraform_ssh_key_path = "${var.test_private_key_path}"
  internal_domain        = "${var.test_internal_domain}"
  cluster_name           = "${var.test_cluster_name}"

  trusted_cidrs = ["${var.test_from_ip}/32"]

  # CoreOS Container Linux configuration
  coreos_ami_owner_id = "${var.test_coreos_ami_owner_id}"
  coreos_ami_pattern  = "${var.test_coreos_ami_pattern}"

  # Etcd cluster configuration
  etcd_version               = "${var.test_etcd_version}"
  etcd_instance_count        = 3
  etcd_instance_type         = "t2.micro"
  etcd_asg_health_check_type = "ELB"

  # Kubernetes master cluster configuration
  hyperkube_tag                    = "${var.test_hyperkube_image}"
  k8s_master_instance_type         = "t2.micro"
  k8s_master_instance_count        = 1
  k8s_master_disk_size             = 16
  k8s_master_asg_health_check_type = "ELB"

  # TLS assets
  k8s_tls_cakey   = "${file("${path.module}/tls/${var.test_cluster_name}/ca.indented.key")}"
  k8s_tls_cacert  = "${file("${path.module}/tls/${var.test_cluster_name}/ca.indented.pem")}"
  k8s_tls_apikey  = "${file("${path.module}/tls/${var.test_cluster_name}/apiserver.indented.key")}"
  k8s_tls_apicert = "${file("${path.module}/tls/${var.test_cluster_name}/apiserver.indented.pem")}"

  # Users with SSH access to our instances and their keys
  usernames = ["terraform"]
  userkeys  = ["${file("${var.test_private_key_path}.pub")}"]
}

module "k8s_worker" {
  source = "../k8s_worker_cluster"

  # Generic configuration
  vpc_name               = "${var.test_vpc_name}"
  vpc_number             = "${var.test_vpc_number}"
  vpc_region             = "${var.test_vpc_region}"
  cloud_config_bucket    = "${var.test_cloud_config_bucket}"
  bastion_ssh_port       = "${var.test_bastion_ssh_port}"
  terraform_ssh_key_path = "${var.test_private_key_path}"
  internal_domain        = "${var.test_internal_domain}"
  cluster_name           = "${var.test_cluster_name}"

  # Worker cluster configuration
  worker_group_name  = "test"
  coreos_ami_id      = "${module.k8s_head.coreos_ami_id}"
  hyperkube_tag      = "${var.test_hyperkube_image}"
  node_instance_type = "t2.micro"
  min_asg_size       = 1
  max_asg_size       = 4
  k8s_node_disk_size = 16
  k8s_node_labels    = "role.node=test"

  k8s_master_endpoint = "${module.k8s_head.k8s_master_endpoint}"
  etcd_endpoint       = "${module.k8s_head.etcd_endpoint}"
  private_subnet_ids  = "${module.k8s_head.private_subnet_ids}"
  sg_ids              = ["${module.k8s_head.sg_vpn_id}"]

  k8s_worker_iam_role_name = "${module.k8s_head.k8s_worker_iam_role_name}"
  k8s_worker_profile_arn   = "${module.k8s_head.k8s_worker_profile_arn}"

  # TLS assets
  k8s_tls_cakey  = "${file("${path.module}/tls/${var.test_cluster_name}/ca.indented.key")}"
  k8s_tls_cacert = "${file("${path.module}/tls/${var.test_cluster_name}/ca.indented.pem")}"

  # Users with SSH access to our instances and their keys
  usernames = ["terraform"]
  userkeys  = ["${file("${var.test_private_key_path}.pub")}"]

  # Necessary during bootstrap, flannel needs etcd to configure the network overlay
  dependency_hooks = "${module.k8s_head.dependency_hook}"
}
