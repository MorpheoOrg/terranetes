/*
 *  Maintainer: Étienne Lafarge <etienne@rythm.co>
 *   Copyright (C) 2017 Morpheo Org - Rythm SAS
 *
 *  see https://github.com/MorpheoOrg/terranetes/COPYRIGHT
 *  and https://github.com/MorpheoOrg/terranetes/LICENSE
 *  for more information.
 */

/*
 * AWS VPC parameters, networking and admin access
 */
variable "vpc_region" {
  description = "The AWS region to create your Kubernetes cluster into."
  type        = "string"
}

variable "vpc_name" {
  description = "Arbitrary name to give to your VPC"
  type        = "string"
}

variable "vpc_number" {
  description = "The VPC number. This will define the VPC IP range in CIDR notation as follows: 10.<vpc_number>.0.0/16"
  type        = "string"
}

variable "cluster_name" {
  description = "The name of the Kubernetes cluster to create (necessary when federating clusters)."
  type        = "string"

  default = "default"
}

variable "usernames" {
  description = "A list of usernames that will be able to SSH onto your instances through the bastion host."
  type        = "list"
}

variable "userkeys" {
  description = "The list of SSH keys your users will use (must appear in the same order as the one defined by the \"usernames\" variable)."
  type        = "list"
}

variable "bastion_ssh_port" {
  description = "The port to use to SSH onto your bastion host (avoid using 22 or 2222, a lot of bots are keeping on trying to scan this ports with random usernames and passwords and it tends to fill the SSHD logs a bit too much sometimes...)"
  type        = "string"
}

variable "terraform_ssh_key_path" {
  description = "Local path to the SSH key terraform will use to bootstrap your etcd cluster and tunnel to the Kubernetes UI."
  type        = "string"
}

variable "trusted_cidrs" {
  description = "A list of CIDRs that will be allowed to connect to the SSH port defined by \"bastion_ssh_port\"."
  type        = "list"
}

variable "cloud_config_bucket" {
  description = "The name of the bucket in which to store your instances cloud-config files."
  type        = "string"
}

variable "internal_domain" {
  description = "The internal domain name suffix to be atted to your etcd & k8s master ELBs (ex. company.int)"
  type        = "string"
}

variable "bastion_extra_units" {
  description = "Extra unit files (don't forget the 4-space indentation) to run on the bastion host"
  type        = "list"
  default     = []
}

variable "bastion_extra_files" {
  description = "Extra files (don't forget the 4-space indentation) to put on the bastion host"
  type        = "list"
  default     = []
}

/*
 * CoreOS base AMI for the whole cluster
 */
variable "coreos_ami_owner_id" {
  description = "The ID of the owner of the CoreOS image you want to use on the AWS marketplace (or yours if you're using your own AMI)."
  default     = "595879546273"
  type        = "string"
}

variable "coreos_ami_pattern" {
  description = "The AMI pattern to use (it can be a full name or contain wildcards, default to the last release of CoreOS on the stable channel)."
  default     = "CoreOS-stable-*"
  type        = "string"
}

variable "virtualization_type" {
  type        = "string"
  default     = "hvm"
  description = "The AWS virtualization type to use (hvm or pv)"
}

/*
 * Etcd auto-scaling group & ELB
 */
variable "etcd_version" {
  description = "The etcd version to use (>v3.1.0)"
  default     = "v3.1.5"
}

variable "etcd_instance_type" {
  description = "The EC2 instance type to use for etcd nodes."
  default     = "t2.micro"
  type        = "string"
}

variable "etcd_instance_count" {
  description = "The number of etcd nodes to use (at least 3 is recommended)."
  type        = "string"
  default     = 3
}

variable "etcd_asg_health_check_type" {
  description = "The health check type to use for the etcd ASG (EC2 or ELB)"
  default     = "EC2"
  type        = "string"
}

variable "etcd_asg_health_check_grace_period" {
  description = "Grace period for the etcd health check"
  default     = "300"
  type        = "string"
}

variable "etcd_disk_size" {
  description = "Disk size on etcd nodes"
  type        = "string"
  default     = 16
}

variable "etcd_extra_units" {
  description = "Extra unit files (don't forget the 4-space indentation) to run on the etcd nodes"
  type        = "list"
  default     = []
}

variable "etcd_extra_files" {
  description = "Extra files (don't forget the 2-space indentation) to be put on the etcd nodes"
  type        = "list"
  default     = []
}

/*
 * Kubernetes master autoscaling group & ELB
 */
variable "hyperkube_tag" {
  description = "The version of Hyperkube to use (should be a valid tag of the official CoreOS image for Kubelet, see here: https://quay.io/repository/coreos/hyperkube?tab=tags)."
  type        = "string"
  default     = "v1.6.6_coreos.1"
}

variable "k8s_master_instance_type" {
  description = "The EC2 instance type to use for Kubernetes master nodes."
  default     = "t2.micro"
  type        = "string"
}

variable "k8s_master_instance_count" {
  description = "The number of Kubernetes nodes to run (2 is recommended)."
  type        = "string"
  default     = 2
}

variable "k8s_master_asg_health_check_type" {
  description = "The number of Kubernetes masters to use (at least 2 if you seek to achieve high availability)."
  default     = "EC2"
  type        = "string"
}

variable "k8s_master_asg_health_check_grace_period" {
  description = "The kubernetes masters' health check grace period"
  default     = "600"
  type        = "string"
}

variable "k8s_master_disk_size" {
  description = "The disk size for Kubernetes master nodes (in GB)"
  type        = "string"
  default     = "16"
}

variable "k8s_tls_cakey" {
  description = "The private key of the CA signing kubernetes API & worker certs"
  type        = "string"
}

variable "k8s_tls_cacert" {
  description = "The public key the CA signing kubernetes API & worker certs"
  type        = "string"
}

variable "k8s_tls_apikey" {
  description = "The private key of the Kubernetes APIServer"
  type        = "string"
}

variable "k8s_tls_apicert" {
  description = "The public key of the Kubernetes APIServer"
  type        = "string"
}

variable "k8s_master_extra_units" {
  description = "Extra unit files (don't forget the 4-space indentation) to run on the master nodes"
  type        = "list"
  default     = []
}

variable "k8s_master_extra_files" {
  description = "Extra files (don't forget the 2-space indentation) to be put on the master nodes"
  type        = "list"
  default     = []
}

/*
 * Flavors to enable (1 is true, default if flavor key is unset, 0 is false)
 */
variable "flavors" {
  default = {
    "system" = [
      # Min ASG size for system nodes
      "1",

      # Max ASG size for system nodes
      "5",

      # List of Kubernetes components to deploy on this flavor (default: all available components)
      "cluster_autoscaler,dns,dns_autoscaler,dashboard,heapster,node_problem_detector,rescheduler",
    ]

    "ingress" = [
      "1",
      "5",
      "nginx-ingress-controller,lego",
    ]
  }
}

/*
 * System nodes
 */
variable "system_node_instance_type" {
  description = "The type of instance to use for system nodes"
  type        = "string"
  default     = "t2.small"
}

variable "system_node_disk_size" {
  description = "The system nodes' disk size in GB"
  type        = "string"
  default     = "16"
}

variable "system_node_extra_units" {
  description = "Extra systemd units to put on system nodes (Cloud Config format, add 4 space indentation)"
  type        = "list"
  default     = []
}

variable "system_node_extra_files" {
  description = "Extra files to put on system nodes (Cloud Config format, add 4 space indentation)"
  type        = "list"
  default     = []
}

variable "cluster_autoscaler_image" {
  description = "Docker image to use for Kubernetes' cluster autoscaler"
  type        = "string"
  default     = "gcr.io/google-containers/cluster-autoscaler:v0.6.0"
}

variable "kube_dns_replicas" {
  description = "Number of kube-dns replicas to run"
  type        = "string"
  default     = "3"
}

variable "kube_dns_image" {
  description = "Docker image to use for kube-dns"
  type        = "string"
  default     = "gcr.io/google_containers/kubedns-amd64:1.9"
}

variable "kube_dns_dnsmasq_image" {
  description = "Docker image to use for kube-dns dnsmasq"
  type        = "string"
  default     = "gcr.io/google_containers/kube-dnsmasq-amd64:1.4"
}

variable "kube_dns_dnsmasq_metrics_image" {
  description = "Docker image to use for kube-dns dnsmasq metrics"
  type        = "string"
  default     = "gcr.io/google_containers/dnsmasq-metrics-amd64:1.0"
}

variable "kube_dns_exechealthz_image" {
  description = "Docker image to use for kube-dns exechealthz"
  type        = "string"
  default     = "gcr.io/google_containers/exechealthz-amd64:1.2"
}

variable "cluster_proportional_autoscaler_image" {
  description = "Cluster proportional autoscaler image to use for kube-dns-autoscaler"
  type        = "string"
  default     = "gcr.io/google_containers/cluster-proportional-autoscaler-amd64:1.1.2"
}

variable "kube_dashboard_image" {
  description = "Docker image to use for kubernetes-dashboard"
  type        = "string"
  default     = "gcr.io/google_containers/kubernetes-dashboard-amd64:v1.6.1"
}

variable "heapster_image" {
  description = "Docker image to use for heapster"
  type        = "string"
  default     = "gcr.io/google_containers/heapster:v1.3.0"
}

variable "addon_resizer_image" {
  description = "Docker image to use for Heapster's add-on resizer"
  type        = "string"
  default     = "gcr.io/google_containers/addon-resizer:1.6"
}

variable "node_problem_detector_image" {
  description = "Image to use for the node problem detector"
  type        = "string"
  default     = "gcr.io/google_containers/node-problem-detector:v0.3.0"
}

variable "rescheduler_image" {
  description = "Image to use for Kubernetes' rescheduler"
  type        = "string"
  default     = "gcr.io/google_containers/rescheduler:v0.3.0"
}

/*
 * Ingress nodes
 */
variable "ingress_node_instance_type" {
  description = "The type of instance to use for ingress nodes"
  type        = "string"
  default     = "t2.micro"
}

variable "ingress_node_disk_size" {
  description = "The ingress nodes' disk size in GB"
  type        = "string"
  default     = "16"
}

variable "ingress_node_extra_units" {
  description = "Extra systemd units to put on system nodes (Cloud Config format, add 4 space indentation)"
  type        = "list"
  default     = []
}

variable "ingress_node_extra_files" {
  description = "Extra files to put on ingress nodes (Cloud Config format, add 4 space indentation)"
  type        = "list"
  default     = []
}

variable "ingress_controller_replicas" {
  description = "Number of replicas (=number of nodes) of our ingress controller to be run"
  type        = "string"
  default     = "1"
}

variable "ingress_controller_image" {
  description = "Image to use for the ingress controller (for now, only nginx is supported)"
  type        = "string"
  default     = "gcr.io/google_containers/nginx-ingress-controller:0.9.0-beta.8"
}

variable "ingress_default_backend_image" {
  description = "Image to use for the default backend of the ingress controller"
  type        = "string"
  default     = "gcr.io/google_containers/defaultbackend:1.0"
}

variable "openvpn_image" {
  description = "The kube-openvpn image to use"
  type        = "string"
  default     = "terranetes/openvpn:latest"
}

variable "vpn_port" {
  description = "The port to use to connect to OpenVPN through the Ingress controller"
  type        = "string"
  default     = "4242"
}

variable "vpn_network" {
  description = "Network for OpenVPN clients"
  type        = "string"
  default     = "10.240.0.0"
}

variable "vpn_subnet" {
  description = "Subnet mask for OpenVPN clients' network"
  type        = "string"
  default     = "255.255.0.0"
}

variable "lego_image" {
  description = "Image to use for kube-lego (Let's Encrypt client for our ingress controller)"
  type        = "string"
  default     = "jetstack/kube-lego:0.1.4"
}

variable "lego_email" {
  description = "Email address to use for Let's Encrypt"
  type        = "string"
  default     = ""
}

variable "acme_url" {
  description = "ACME Server URL (defaults to Let's Encrypt staging server)"
  type        = "string"
  default     = "https://acme-staging.api.letsencrypt.org/directory"
}
