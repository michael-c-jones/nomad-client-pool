
#  terraform module to establish a nomad-server cluster

variable env {
  type = "map"
}

variable chef {
  type = "map"
}


variable id {
}

variable datacenter {
}

variable region {
}

variable subnets {
  type = "list"
}


variable ephemeral_port_range {
  type = "map"

  default = {
    min = "20000"
    max = "32000"
  }
}


variable security_group_ids {
  type = "list"
}

variable iam_policy {}

variable node_count {}

variable disable_api_termination {
  default = "true"
}

variable chef_runlist {
  type = "list"
  default = [ "role[nomad-client]" ]
}

variable instance_type {
  type = "string"
}

variable volume_size {
  type = "string"
  default = "256"
}

variable ami_owner {
  default = "099720109477"
}

variable ami_name {
  default = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-20181012"
}

variable asg_min {
  default = "1"
}
variable asg_max {
  default = "1"
}

variable scale_up_cpu {
  default = "70"
}

variable scale_down_cpu {
  default = "50"
}

