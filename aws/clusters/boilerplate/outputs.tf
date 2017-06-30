## OUTPUTS ##
output "vpc_id" {
  value = "${module.k8s_head.vpc_id}"
}

output "public_route_table_id" {
  value = "${module.k8s_head.public_route_table_id}"
}

output "private_route_table_id" {
  value = "${module.k8s_head.private_route_table_id}"
}

output "coreos_ami_id" {
  value = "${module.k8s_head.coreos_ami_id}"
}

output "cloud_config_bucket" {
  value = "${module.k8s_head.cloud_config_bucket}"
}

output "etcd_endpoint" {
  value = "${module.k8s_head.etcd_endpoint}"
}

output "k8s_master_endpoint" {
  value = "${module.k8s_head.k8s_master_endpoint}"
}

output "k8s_worker_iam_role_name" {
  value = "${module.k8s_head.k8s_worker_iam_role_name}"
}

output "k8s_worker_profile_arn" {
  value = "${module.k8s_head.k8s_worker_profile_arn}"
}

output "private_subnet_ids" {
  value = "${module.k8s_head.private_subnet_ids}"
}

output "public_subnet_ids" {
  value = "${module.k8s_head.public_subnet_ids}"
}

output "route53_internal_zone_id" {
  value = "${module.k8s_head.route53_internal_zone_id}"
}

output "sg_vpn_id" {
  value = "${module.k8s_head.sg_vpn_id}"
}

output "dependency_hook" {
  value = "${module.k8s_head.dependency_hook}"
}
