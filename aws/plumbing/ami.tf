/*
 * Configuration for our AMI(s): the base CoreOS one to bootstrap... everything
 * actually !! We can use cloud-config files to add our users and public keys,
 * software that matters for us (etcd, flannel, kubernetes master, kubelet...)
 *
 * The discrimination between the images isn't done at the AMI level anymore,
 * which is a great thing: we won't need to automate the build of our AMIs, the
 * configuration is stored as text... but we don't need tools like Ansible or
 * Chef. Also we'll never ever pay for custom AMIs... the best of both world and
 * even more.
 *
 * Only thing to pay attention to: the Docker Image registry will need to be
 * internalized at some point (at least for our base images and also the public
 * ones we fetch from DockerHub when relevant) in order to make bootstraping
 * instances as fast as possible.
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

# The CoreOS AMI we're using (almost) everywhere
data "aws_ami" "coreos_stable" {
  most_recent = true

  filter {
    name   = "name"
    values = ["${var.coreos_ami_pattern}"]
  }

  filter {
    name   = "virtualization-type"
    values = ["${var.virtualization_type}"]
  }

  owners = ["${var.coreos_ami_owner_id}"]
}
