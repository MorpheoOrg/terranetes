module "foundations" {
  source = "../../plumbing"

  vpc_name            = "${var.test_vpc_name}"
  vpc_number          = "${var.test_vpc_number}"
  vpc_region          = "${var.test_vpc_region}"
  cluster_name        = "${var.test_cluster_name}"
  usernames           = ["terraform"]
  userkeys            = ["${file("~/.ssh/terraform.pub")}"]
  bastion_ssh_port    = "${var.test_bastion_ssh_port}"
  trusted_cidrs       = ["${var.test_from_ip}/32"]
  coreos_ami_owner_id = "${var.test_coreos_ami_owner_id}"
  coreos_ami_pattern  = "${var.test_coreos_ami_pattern}"
  cloud_config_bucket = "${var.test_cloud_config_bucket}"
  internal_domain     = "${var.test_internal_domain}"
}

module "etcd_cluster" {
  source = "../../etcd_cluster"

  vpc_name                   = "${var.test_vpc_name}"
  vpc_number                 = "${var.test_vpc_number}"
  vpc_region                 = "${var.test_vpc_region}"
  cluster_name               = "${var.test_cluster_name}"
  coreos_ami_id              = "${module.foundations.coreos_ami_id}"
  cloud_config_bucket        = "${module.foundations.cloud_config_bucket}"
  etcd_version               = "${var.test_etcd_version}"
  etcd_instance_type         = "t2.micro"
  etcd_instance_count        = "3"
  etcd_asg_health_check_type = "ELB"
  sg_vpn_id                  = "${module.foundations.sg_vpn_id}"
  etcd_iam_role_name         = "${module.foundations.etcd_iam_role_name}"
  etcd_iam_profile_arn       = "${module.foundations.etcd_iam_profile_arn}"
  route53_internal_zone_id   = "${module.foundations.route53_internal_zone_id}"
  bastion_ip                 = "${module.foundations.bastion_ip}"
  bastion_ssh_port           = "${var.test_bastion_ssh_port}"
  terraform_ssh_key_path     = "${var.test_private_key_path}"
  cloud_config_bucket        = "${module.foundations.cloud_config_bucket}"
  private_subnet_ids         = "${module.foundations.private_subnet_ids}"
  internal_domain            = "${var.test_internal_domain}"
  usernames                  = ["terraform"]
  userkeys                   = ["${file("~/.ssh/terraform.pub")}"]
}
