#
#  terraform module to establish a nomad cluster
#  running underneath a load balancer
#

locals {
  nomad_name_prefix = "nomad-client-${var.id}-${var.env["full_name"]}"
  ephemeral_sg_name = "nomad-ephemeral-${var.id}-${var.env["full_name"]}"
}

data "aws_subnet" "subnets" {
  count = "${length(var.subnets)}"
  id    = "${element(var.subnets, count.index)}"
}


resource "aws_instance" "nomad" {
  count = "${var.node_count}"

  ami                  = "${data.aws_ami.nomad.id}"
  instance_type        = "${var.instance_type}"
  iam_instance_profile = "${aws_iam_instance_profile.nomad.name}"

  vpc_security_group_ids  = [ 
    "${aws_security_group.ephemeral.id}",
    "${var.security_group_ids}"
  ]

  subnet_id               = "${element(var.subnets, count.index)}"
  key_name                = "${var.chef["infra_key"]}"
  disable_api_termination = "${var.disable_api_termination}"

  root_block_device {
    volume_type = "gp2"
    volume_size = "${var.volume_size}"
    delete_on_termination = "true"
  }

  provisioner "remote-exec" {
    connection {
      host         = "${self.private_ip}"
      user         = "ubuntu"
      private_key  = "${var.chef["private_key"]}"
      bastion_host = "${var.chef["bastion_host"]}"
      bastion_user = "${var.chef["bastion_user"]}"
      bastion_private_key = "${var.chef["bastion_private_key"]}"
    }
    inline = [
      "sudo mkdir -p /etc/chef/ohai/hints",
      "sudo touch /etc/chef/ohai/hints/ec2.json"
    ]
  }
  provisioner "chef" {
    connection {
      host         = "${self.private_ip}"
      user         = "ubuntu"
      private_key  = "${var.chef["private_key"]}"
      bastion_host = "${var.chef["bastion_host"]}"
      bastion_user = "${var.chef["bastion_user"]}"
      bastion_private_key = "${var.chef["bastion_private_key"]}"
    }

    attributes_json = <<EOF
    {
        "nomad-client": {
            "config": {
                "datacenter": "${var.datacenter}",
                "region":     "${var.region}",
                "id": "${var.id}"
            }
        }
    }
    EOF

    version     = "${var.chef["client_version"]}"
    environment = "${var.chef["environment"]}"
    run_list    = "${var.chef_runlist}"
    node_name   = "${local.nomad_name_prefix}-${format("%02d", count.index)}"
    server_url  = "${var.chef["server"]}"
    user_name   = "${var.chef["validation_client"]}"
    user_key    = "${var.chef["validation_key"]}"
  }

  tags {
    Name           = "${local.nomad_name_prefix}-${format("%02d", count.index)}"
    vpc            = "${var.env["vpc"]}"
    environment    = "${var.chef["environment"]}"
    env            = "${var.env["full_name"]}"
    provisioned_by = "terraform"
    configured_by  = "chef"
    chef_runlist   = "${join(",", var.chef_runlist)}"
    nomad_dc       = "${var.datacenter}"
    nomad_region   = "${var.region}"
  }

  lifecycle {
    ignore_changes = [
      "ami",
      "user_data"
    ]
  }
}


## security stuff

resource "aws_security_group" "ephemeral" {
  name        = "${local.ephemeral_sg_name}"
  description = "Allow internode communication between nomad clients and servers"
  vpc_id      = "${var.env["vpc"]}"

  tags {
    Name           = "${local.nomad_name_prefix}"
    vpc            = "${var.env["vpc"]}"
    environment    = "${var.env["name"]}"
    provisioned_by = "terraform"
  }
}

resource "aws_security_group_rule" "ingress_tcp" {
  type              = "ingress"
  from_port         = "${var.ephemeral_port_range["min"]}"
  to_port           = "${var.ephemeral_port_range["max"]}"
  protocol          = "tcp"
  self              = true
  security_group_id = "${aws_security_group.ephemeral.id}"
}

resource "aws_security_group_rule" "egress_tcp" {
  type              = "egress"
  from_port         = "${var.ephemeral_port_range["min"]}"
  to_port           = "${var.ephemeral_port_range["max"]}"
  protocol          = "tcp"
  self              = true
  security_group_id = "${aws_security_group.ephemeral.id}"
}

resource "aws_security_group_rule" "ingress_udp" {
  type              = "ingress"
  from_port         = "${var.ephemeral_port_range["min"]}"
  to_port           = "${var.ephemeral_port_range["max"]}"
  protocol          = "udp"
  self              = true
  security_group_id = "${aws_security_group.ephemeral.id}"
}

resource "aws_security_group_rule" "egress_udp" {
  type              = "egress"
  from_port         = "${var.ephemeral_port_range["min"]}"
  to_port           = "${var.ephemeral_port_range["max"]}"
  protocol          = "udp"
  self              = true
  security_group_id = "${aws_security_group.ephemeral.id}"
}

# ami lookup
data "aws_ami" "nomad" {
  most_recent = true

  filter {
    name   = "root-device-type"
    values = [ "ebs"]
  }

  name_regex = "${var.ami_name}"
  owners     = [ "${var.ami_owner}" ]
}

# iam profile stuff

resource "aws_iam_instance_profile" "nomad" {
  name = "${local.nomad_name_prefix}"
  role = "${aws_iam_role.nomad.name}"
}

resource "aws_iam_role" "nomad" {
  name               = "${local.nomad_name_prefix}-${var.env["shortregion"]}"
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

resource "aws_iam_policy" "nomad" {
  name   = "${local.nomad_name_prefix}-${var.env["shortregion"]}"
  policy = "${var.iam_policy}"
}

resource "aws_iam_policy_attachment" "nomad" {
  name       = "${local.nomad_name_prefix}-${var.env["shortregion"]}"
  roles      = [ "${aws_iam_role.nomad.name}" ]
  policy_arn = "${aws_iam_policy.nomad.arn}"
}
