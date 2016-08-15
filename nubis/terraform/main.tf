
provider "aws" {
    profile = "${var.aws_profile}"
    region  = "${var.aws_region}"
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
        Region              = "${var.aws_region}"
        Environment         = "${var.environments}"
        TechnicalContact    = "${var.technical_contact}"
    }
}

resource "atlas_artifact" "nubis-user-management" {
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
    image_id = "${ element(split(",",replace(atlas_artifact.nubis-user-management.id,":",",")) ,1 + index(split(",",replace(atlas_artifact.nubis-user-management.id,":",",")), var.aws_region)) }"

    instance_type   = "t2.nano"
    key_name        = "${var.ssh_key_name}"

    security_groups = [
      "${aws_security_group.user-management.id}",
      "${var.internet_security_group_id}",
      "${var.shared_services_security_group_id}",
    ]

    user_data = <<EOF
NUBIS_PROJECT=${var.project}
NUBIS_ENVIRONMENT=${var.environments}
NUBIS_ACCOUNT=${var.service_name}
NUBIS_DOMAIN=${var.domain}
EOF

}

resource "aws_iam_role" "user-management" {
  count = "${var.enabled}"

  lifecycle {
    create_before_destroy = true
  }

  name = "${var.project}-${var.environments}-${var.aws_region}"
  path = "/nubis/user-management/"

  assume_role_policy = <<POLICY
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
POLICY
}

resource "aws_iam_role_policy" "user-management" {
    count   = "${var.enabled}"
    name    = "${var.project}-${var.environments}-${var.aws_region}"
    role    = "${aws_iam_role.user-management.id}"

    policy  = <<EOF
{
    "Version": "2012-10-17"
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:AttachRolePolicy",
                "iam:AttachUserPolicy",
                "iam:CreateAccessKey",
                "iam:CreateRole",
                "iam:CreateUser",
                "iam:DeleteAccessKey",
                "iam:DeleteGroupPolicy",
                "iam:DeleteUser",
                "iam:DeleteUserPolicy",
                "iam:GetPolicy",
                "iam:GetPolicyVersion",
                "iam:GetRole",
                "iam:GetRolePolicy",
                "iam:GetUser",
                "iam:GetUserPolicy",
                "iam:ListAttachedRolePolicies",
                "iam:ListAttachedUserPolicies",
                "iam:ListInstanceProfiles",
                "iam:ListInstanceProfilesForRole",
                "iam:ListPolicies",
                "iam:ListRolePolicies",
                "iam:ListRoles",
                "iam:ListUserPolicies",
                "iam:ListUsers",
                "iam:PutRolePolicy",
                "iam:PutUserPolicy",
                "iam:UpdateLoginProfile",
                "iam:UpdateUser"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}
