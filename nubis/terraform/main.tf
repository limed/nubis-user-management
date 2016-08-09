
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
