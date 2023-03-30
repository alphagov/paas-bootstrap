resource "aws_security_group" "concourse" {
  # Web

  name        = "${var.env}-concourse"
  description = "Concourse security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.concourse-elb.id]
  }

  ingress {
    from_port = 6868
    to_port   = 6868
    protocol  = "tcp"
    cidr_blocks = compact(
      concat(
        var.admin_cidrs,
        [format("%s/32", var.microbosh_static_private_ip)],
        var.user_static_cidrs,
      ),
    )
  }

  tags = {
    Name = "${var.env}-concourse"
  }
}

resource "aws_security_group" "concourse-worker" {
  # Worker

  name        = "${var.env}-concourse-worker"
  description = "Concourse worker security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    # ATC -> Garden
    from_port       = 7777
    to_port         = 7777
    protocol        = "tcp"
    security_groups = [aws_security_group.concourse.id]
  }

  ingress {
    # ATC -> Baggageclaim
    from_port       = 7788
    to_port         = 7788
    protocol        = "tcp"
    security_groups = [aws_security_group.concourse.id]
  }

  ingress {
    from_port = 6868
    to_port   = 6868
    protocol  = "tcp"
    cidr_blocks = compact(
      concat(
        var.admin_cidrs,
        [format("%s/32", var.microbosh_static_private_ip)],
        var.user_static_cidrs,
      ),
    )
  }

  tags = {
    Name = "${var.env}-concourse-worker"
  }
}

resource "aws_security_group" "concourse-nocycle" {
  # Web (again)

  # This security group exists because we use ingress/egress rules inline

  # We cannot use inline rules where there are cycles

  name        = "${var.env}-concourse-nocycle"
  description = "Concourse nocycle security group"
  vpc_id      = var.vpc_id

  ingress {
    # TSA <- Beacon
    from_port       = 2222
    to_port         = 2222
    protocol        = "tcp"
    security_groups = [aws_security_group.concourse-worker.id]
  }

  tags = {
    Name = "${var.env}-concourse-no-cycle"
  }
}

