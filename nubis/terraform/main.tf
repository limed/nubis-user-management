
provider "aws" {
    profile = "${var.aws_profile}"
    region  = "${var.region}"
}

resource "aws_security_group" "user-management" {
    count       = "${var.enabled}"
    name        = "user-management"
    description = "Allow inbound connection for user management node"

    vpc_id = "${var.vpc_id}"

    ingress {
        from_port       = 22
        to_port         = 22
        protocol        = "tcp"
        security_groups = [
            "${var.ssh_security_group_id}"
        ]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Region              = "${var.region}"
        Environment         = "${var.environment}"
        TechnicalContact    = "${var.technical_contact}"
    }
}

resource "atlas_artifact" "nubis-nat" {
  count = "${var.enabled}"

  lifecycle {
    create_before_destroy = true
  }

  name = "nubisproject/nubis-user-management"
  type = "amazon.image"

  metadata {
    project_version = "${var.nubis_version}"
  }
}

resource "aws_autoscaling_group" "user-management" {
    count               = "${var.enabled}"
    name                = "user-management-${var.project} - ${aws_launch_configuration.user-management.name}"
    vpc_zone_identifier = ["${split(",", var.private_subnets)}"]

    max_size                = "2"
    min_size                = "0"
    desired_capacity        = "1"
    launch_configuration    = "${aws_launch_configuration.user-management.name}"

    tags {
        key                 = "Name"
        value               = "user-management (${var.nubis_version}) for ${var.account_name})"
        propogate_at_launch = true
    }

    tag {
        key                 = "ServiceName"
        value               = "${var.account_name}"
        propagate_at_launch = true
    }

    tag {
        key                 = "TechnicalContact"
        value               = "${var.technical_contact}"
        propagate_at_launch = true
    }

    tag {
        key                 = "Environment"
        value               = "${var.environments}"
        propagate_at_launch = true
    }

}

resource "aws_launch_configuration" "user-management" {
    count = "${var.enabled}"

    # Somewhat nasty, since Atlas doesn't have an elegant way to access the id for a region
    # the id is "region:ami,region:ami,region:ami"
    # so we split it all and find the index of the region
    # add on, and pick that element
    image_id = "${ element(split(",",replace(atlas_artifact.nubis-user-management.id,":",",")) ,1 + index(split(",",replace(atlas_artifact.nubis-user-management.id,":",",")), var.region)) }"

    instance_type   = "t2.nano"
    key_name        = "${var.key_name}"

    security_groups = [
      "${aws_security_group.user-management.id}",
      "${var.internet_security_group_id}",
      "${var.shared_services_security_group_id}",
    ]

    user_data = <<EOF
NUBIS_PROJECT=${var.project}
NUBIS_ENVIRONMENT=${var.environment}
NUBIS_ACCOUNT=${var.service_name}
NUBIS_DOMAIN=${var.domain}
EOF

}
