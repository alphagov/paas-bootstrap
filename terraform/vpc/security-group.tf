data "aws_instances" "concourse_workers" {
  filter {
    name   = "tag:instance_group"
    values = ["concourse-worker", "concourse-lite"]
  }

  filter {
    name   = "tag:deploy_env"
    values = [var.env]
  }
}

resource "aws_security_group" "office-access-ssh" {
  vpc_id      = aws_vpc.paas.id
  name        = "${var.env}-office-access-ssh"
  description = "Allow access from office"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = compact(concat(var.admin_cidrs, var.set_concourse_egress_cidrs == false ? [] : formatlist("%s/32", data.aws_instances.concourse_workers.public_ips)))
  }

  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = compact(concat(var.admin_cidrs, var.set_concourse_egress_cidrs == false ? [] : formatlist("%s/32", data.aws_instances.concourse_workers.public_ips)))
  }

  tags = {
    Name = "${var.env}-office-access-ssh"
  }
}

