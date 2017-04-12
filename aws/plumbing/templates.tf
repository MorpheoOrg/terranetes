/*
 *  Maintainer: Étienne Lafarge <etienne@rythm.co>
 *   Copyright (C) 2017 Morpheo Org - Rythm SAS
 *
 *  see https://github.com/MorpheoOrg/terranetes/COPYRIGHT
 *  and https://github.com/MorpheoOrg/terranetes/LICENSE
 *  for more information.
 */

##### CLOUD CONFIG TO DOWNLOAD MORE CLOUD CONFIG FROM S3 (0_o) ######
data "template_file" "bastion_s3_cloud_config" {
  template = "${file("${path.module}/../cloud-configs/run_s3_cloud_config.yml")}"

  vars {
    bucket_region         = "${var.vpc_region}"
    bucket                = "${aws_s3_bucket.cloud_config.bucket}"
    key                   = "${aws_s3_bucket_object.bastion_cloud_config.key}"
    iam_cloud_config_role = "${aws_iam_role.bastion.name}"
  }
}

###### USERS WITH SSH ACCESS TO OUR EC2 INSTANCES ######
data "template_file" "user" {
  count    = "${length(var.usernames)}"
  template = "${file("${path.module}/../cloud-configs/user_cloud_config.yml")}"

  vars {
    username   = "${element(var.usernames, count.index)}"
    public_keys = "      - ${join("\n      - ", split(",", element(var.userkeys, count.index)))}"
  }
}
