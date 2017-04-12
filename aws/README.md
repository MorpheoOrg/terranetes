TerraNetes: cluster plumbing
============================

TODO: design graph

TODO: notes about network topology and IP Addressing

This creates a new VPC that spans all the possible availability zones in its
region, with one public/private subnet pair in each AZ.
Corresponding security groups and route tables are also created.

A NAT device for instances in private subnets to talk to the internet is also
created, as well as a bastion host you'll be able to use to connect to private
instances in the cluster.

It also creates the IAM roles necessary for our Kubernetes cluster, an internal
DNS zone in route53 (for the ELB in front of the k8s masters), S3 buckets whence
all Container Linux instances will retrieve their `cloud-config`.
