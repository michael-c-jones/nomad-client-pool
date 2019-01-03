
## outputs for nomad module

output "instances" {
  value = [  "${aws_instance.nomad.*.id}" ]
}

output "ephemeral_sg" {
  value = [  "${aws_security_group.ephemeral.id}" ]
}
