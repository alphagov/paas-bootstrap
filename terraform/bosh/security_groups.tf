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

resource "aws_security_group" "bosh" {
  name        = "${var.env}-bosh"
  description = "Bosh security group"
  vpc_id      = var.vpc_id

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
    cidr_blocks = var.set_concourse_egress_cidrs == false ? [] : formatlist("%s/32", data.aws_instances.concourse_workers.public_ips)
  }

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    security_groups = [
      aws_security_group.bosh_ssh_client.id,
    ]
  }

  ingress {
    from_port   = 6868
    to_port     = 6868
    protocol    = "tcp"
    cidr_blocks = var.set_concourse_egress_cidrs == false ? [] : formatlist("%s/32", data.aws_instances.concourse_workers.public_ips)
  }

  ingress {
    from_port = 6868
    to_port   = 6868
    protocol  = "tcp"

    security_groups = [
      aws_security_group.bosh_api_client.id,
    ]
  }

  ingress {
    from_port = 8443
    to_port   = 8443
    protocol  = "tcp"

    security_groups = [
      aws_security_group.bosh_api_client.id,
    ]
  }

  ingress {
    from_port = 8844
    to_port   = 8844
    protocol  = "tcp"

    security_groups = [
      aws_security_group.bosh_api_client.id,
    ]
  }

  ingress {
    from_port = 9100
    to_port   = 9100
    protocol  = "tcp"

    security_groups = [
      aws_security_group.bosh_api_client.id,
    ]
  }

  ingress {
    from_port = 9275
    to_port   = 9275
    protocol  = "tcp"

    security_groups = [
      aws_security_group.bosh_api_client.id,
    ]
  }

  ingress {
    from_port = 25555
    to_port   = 25555
    protocol  = "tcp"

    security_groups = [
      aws_security_group.bosh_api_client.id,
    ]
  }

  ingress {
    from_port = 4222
    to_port   = 4222
    protocol  = "tcp"

    security_groups = [
      aws_security_group.bosh_managed.id,
    ]
  }

  ingress {
    from_port = 25250
    to_port   = 25250
    protocol  = "tcp"

    security_groups = [
      aws_security_group.bosh_managed.id,
    ]
  }

  ingress {
    from_port = 25777
    to_port   = 25777
    protocol  = "tcp"

    security_groups = [
      aws_security_group.bosh_managed.id,
    ]
  }

  tags = {
    Name = "${var.env}-bosh"
  }
}

resource "aws_security_group" "bosh_api_client" {
  name        = "${var.env}-bosh-api-client"
  description = "Default security group for VMs which will interact with bosh API"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.env}-bosh-api-client"
  }
}

resource "aws_security_group" "bosh_ssh_client" {
  name        = "${var.env}-bosh-ssh-client"
  description = "Security group for VMs that can SSH into BOSH"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.env}-bosh-ssh-client"
  }
}

resource "aws_security_group" "bosh_managed" {
  name        = "${var.env}-bosh-managed"
  description = "Default security group for VMs managed by Bosh"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${var.env}-bosh-managed"
  }
}

