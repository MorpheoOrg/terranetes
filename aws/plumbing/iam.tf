/*
 * IAM Policies for our Kubernetes cluster. Kubernetes creates ELBs when
 * deploying publicly available services, it can also create EBS volumes when
 * using persistent volumes and our CoreOS instances must have permissions to
 * access their cloud-config bucket. That's basically what this file describes.
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

resource "aws_iam_policy" "cloud_config_bucket_access" {
  name        = "s3-cloud-config-${var.cluster_name}"
  path        = "/"
  description = "Grants read access to the S3 bucket holding our cloud-config files for CoreOS."

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketLocation",
        "s3:ListAllMyBuckets"
      ],
      "Resource": "arn:aws:s3:::*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::${var.cloud_config_bucket}"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": ["arn:aws:s3:::${var.cloud_config_bucket}/*"]
    }
  ]
}
EOF
}

resource "aws_iam_policy" "route53_rw_access" {
  name        = "route53-rw-access-${var.cluster_name}"
  path        = "/"
  description = "Allow the route53-kubernetes pods to write public DNS routes to ELBs in Route53 for our public services"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["route53:ListHostedZonesByName"],
            "Resource": ["*"]
        },
        {
            "Effect": "Allow",
            "Action": "elasticloadbalancing:DescribeLoadBalancers",
            "Resource": ["*"]
        },
        {
            "Effect": "Allow",
            "Action": "route53:ChangeResourceRecordSets",
            "Resource": ["*"]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "elb_control" {
  name        = "elb-control-${var.cluster_name}"
  path        = "/"
  description = "Allows the kube controller manager to create ELBs for public services"

  # TODO: more restrictive policies or at least more explicit ones
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["elasticloadbalancing:*"],
            "Resource": ["*"]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "ebs_control" {
  name        = "ebs-control-${var.cluster_name}"
  path        = "/"
  description = "Allows Kubernetes to create EBS volumes"

  # TODO FIXME: more restrictive policies or at least more explicit ones
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["ec2:*"],
            "Resource": ["*"]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "autoscaling_control" {
  name        = "autoscaling-control-${var.cluster_name}"
  path        = "/"
  description = "Allows Kubernetes autoscaler to change the number of desired instances in a given worker autoscaling group."

  # TODO FIXME: more restrictive policies or at least more explicit ones
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_policy_attachment" "ec2_cloud_config_bucket_access" {
  name       = "cloud-config-ec2-bucket-access-${var.cluster_name}"
  policy_arn = "${aws_iam_policy.cloud_config_bucket_access.arn}"

  roles = ["${aws_iam_role.bastion.name}", "${aws_iam_role.etcd.name}", "${aws_iam_role.k8s_master.name}", "${aws_iam_role.k8s_worker.name}"]
}

resource "aws_iam_policy_attachment" "k8s_elb_control" {
  name       = "kubernetes-elb-control-${var.cluster_name}"
  policy_arn = "${aws_iam_policy.elb_control.arn}"

  # roles = ["${aws_iam_role.k8s_master.name}"]
  roles = ["${aws_iam_role.k8s_master.name}", "${aws_iam_role.k8s_worker.name}"]
}

resource "aws_iam_policy_attachment" "k8s_ebs_control" {
  name       = "kubernetes-ebs-control-${var.cluster_name}"
  policy_arn = "${aws_iam_policy.ebs_control.arn}"

  roles = ["${aws_iam_role.k8s_master.name}", "${aws_iam_role.k8s_worker.name}"]
}

resource "aws_iam_policy_attachment" "k8s_autoscaling_control" {
  name       = "kubernetes-autoscaling-control-${var.cluster_name}"
  policy_arn = "${aws_iam_policy.autoscaling_control.arn}"

  roles = ["${aws_iam_role.k8s_master.name}", "${aws_iam_role.k8s_worker.name}"]
}

resource "aws_iam_policy_attachment" "external_dns_manager" {
  name       = "kubernetes-external-dns-manager-${var.cluster_name}"
  policy_arn = "${aws_iam_policy.route53_rw_access.arn}"

  roles = ["${aws_iam_role.k8s_master.name}", "${aws_iam_role.k8s_worker.name}"]
}

resource "aws_iam_role" "bastion" {
  name = "bastion-${var.cluster_name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role" "etcd" {
  name = "etcd-${var.cluster_name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role" "k8s_master" {
  name = "kubernetes-master-${var.cluster_name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role" "k8s_worker" {
  name = "kubernetes-worker-${var.cluster_name}"

  lifecycle {
    create_before_destroy = true
  }

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "bastion" {
  name  = "bastion-${var.cluster_name}"
  roles = ["${aws_iam_role.bastion.name}"]
}

resource "aws_iam_instance_profile" "etcd" {
  name  = "etcd-${var.cluster_name}"
  roles = ["${aws_iam_role.etcd.name}"]
}

resource "aws_iam_instance_profile" "k8s_master" {
  name  = "kubernetes-master-${var.cluster_name}"
  roles = ["${aws_iam_role.k8s_master.name}"]
}

resource "aws_iam_instance_profile" "k8s_worker" {
  name  = "kubernetes-worker-${var.cluster_name}"
  roles = ["${aws_iam_role.k8s_worker.name}"]

  lifecycle {
    create_before_destroy = true
  }
}
