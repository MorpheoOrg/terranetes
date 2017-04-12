/*
 * Template for a VPC (can be used in as many regions as you'd like to).
 *
 * IMPORTANT NOTE ABOUT THE VPC's CIDR: the last two bits of the second byte of
 * the IP are used to define the Network role:
 *  - 0 ~ (00): "Physical" (virtual) machines: EC2/RDS instances, ELBs...
 *  - 1 ~ (01): Kubernetes Pods
 *  - 2 ~ (10): Kubernetes services
 *
 * The main consequence is that VPC numbers must be multiples of 4, not to be
 * forgotten when creating new ones.
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

#########   THE VPC ITSELF   #########
resource "aws_vpc" "main" {
  cidr_block = "10.${var.vpc_number}.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true
  enable_dns_support = true

  tags{
      Name = "${var.vpc_name}"
      Origin = "Terraform"
      KubernetesCluster = "${var.cluster_name}"
  }
}

/*
 * The internet gateway making communication between machines in our VPC and the
 * Internet possible (and smooth since AWS auto-scales it without us having to do
 * anything :) )
 */
resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
      Name = "${var.vpc_name}-igw"
      Origin = "Terraform"
  }
}

/*
 * A NAT gateway for private instance to access the Web
 */
resource "aws_eip" "nat_device" {
  vpc      = true
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = "${aws_eip.nat_device.id}"
  subnet_id = "${element(aws_subnet.public.*.id, 0)}"

  depends_on = ["aws_internet_gateway.igw"]
}

/*
 * A VPC endpoint to Amazon S3: allows instances in private subnets to connect
 * to Amazon S3 to fetch cloud-configs while making sure we don't go through the
 * public Web. The connection is obviously made over HTTPs (that's not a reason
 * to put secrets that are too secret in cloud configs stored on S3 though).
 */
resource "aws_vpc_endpoint" "s3_endpoint" {
  service_name = "com.amazonaws.${var.vpc_region}.s3"
  vpc_id = "${aws_vpc.main.id}"
  route_table_ids = ["${aws_route_table.private.id}"]
}

/*
 * The route tables for our VPC (the mental model is the same as a router
 * connected to all subnets in our VPC, we put routes in there, that's all,
 * there's nothing more to understand).
 */
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"

  # Route to the internet via Internet Gateways
  route {
      # How machines usually connect to the internet
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.igw.id}"
  }

  tags {
      Name = "${var.vpc_name}-public-route-table"
      KubernetesCluster = "${var.cluster_name}"
      Origin = "Terraform"
  }
}

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.main.id}"

  route {
      # How instances in private subnets connect to the Internet
      cidr_block = "0.0.0.0/0"
      nat_gateway_id = "${aws_nat_gateway.natgw.id}"
  }

  tags {
      Name = "${var.vpc_name}-internal-internet-route-table"
      KubernetesCluster = "${var.cluster_name}"
      Origin = "Terraform"
  }

  lifecycle {
    ignore_changes = ["route"]
  }
}

############   SUBNETS   #############
/*
 * TODO FIXME: check the status on that possibility
 * This subnet configuration will work in a future version of Terraform. We'll use it since it allows us to
 * automatically spread our cluster to all availability zones in regions, no matter how many they are.
 *
 * data "aws_availability_zones" "list" {}
 *
 * resource "aws_subnet" "public" {
 *   count = "${length(data.aws_availability_zones.list.names)}"
 *   vpc_id = "${aws_vpc.main.id}"
 *   cidr_block = "10.${var.vpc_number}.${256/(length(data.aws_availability_zones.list.names) + length(data.aws_availability_zones.list.names) % 2) * count.index}.0/${17 + 2*(length(data.aws_availability_zones.list.names) % 2)}"
 *   availability_zone = "${element(data.aws_availability_zones.list.names, count.index)}"
 *
 *   map_public_ip_on_launch = true
 *
 *   tags {
 *       Name = "${var.vpc_name}-subnet-public-${count.index}"
 *       SubnetGroup = "primary"
 *       SubnetExposure = "public"
 *       Origin = "Terraform"
 *   }
 * }
 *
 * resource "aws_subnet" "private" {
 *   count = "${length(data.aws_availability_zones.list.names)}"
 *   vpc_id = "${aws_vpc.main.id}"
 *   cidr_block = "10.${var.vpc_number}.${256/(length(data.aws_availability_zones.list.names) + length(data.aws_availability_zones.list.names) % 2) * count.index + 32*(4 - length(data.aws_availability_zones.list.names))}.0/${17 + 2*(length(data.aws_availability_zones.list.names) % 2)}"
 *   availability_zone = "${data.aws_availability_zones.list.names[count.index]}"
 *
 *   map_public_ip_on_launch = false
 *
 *   tags {
 *       Name = "${var.vpc_name}-subnet-private-${count.index}"
 *       SubnetGroup = "primary"
 *       SubnetExposure = "private"
 *       Origin = "Terraform"
 *   }
 * }
 *
 * resource "aws_route_table_association" "private-nat" {
 *   count = "${length(data.aws_availability_zones.list.names)}"
 *   subnet_id = "${element(aws_subnet.private.*.id, count.index)}"
 *   route_table_id = "${aws_route_table.nat.id}"
 * }
 */

// Gets all the available AZs in the region and spans our subnets across all
// these for the maximum amount of possible redundancy (for a really zone
// failure tolerant etcd deployment, 3 zones at least are required)
data "aws_availability_zones" "list" {}

resource "aws_subnet" "public" {
  count = "2"
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "10.${var.vpc_number}.${128 * count.index}.0/18"
  availability_zone = "${element(data.aws_availability_zones.list.names, count.index)}"

  map_public_ip_on_launch = true

  tags {
      Name = "${var.vpc_name}-subnet-public-${count.index}"
      SubnetExposure = "public"
      KubernetesCluster = "${var.cluster_name}"
      Origin = "Terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route_table_association" "public" {
  count = "2"
  subnet_id = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_subnet" "private" {
  count = "2"
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "10.${var.vpc_number}.${128 * count.index + 64}.0/18"
  availability_zone = "${data.aws_availability_zones.list.names[count.index]}"

  map_public_ip_on_launch = false

  tags {
      Name = "${var.vpc_name}-subnet-private-${count.index}"
      SubnetExposure = "private"
      KubernetesCluster = "${var.cluster_name}"
      Origin = "Terraform"
  }
}

resource "aws_route_table_association" "private" {
  count = "2"
  subnet_id = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${aws_route_table.private.id}"
}
