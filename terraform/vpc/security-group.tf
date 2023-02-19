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
    cidr_blocks = compact(concat(var.admin_cidrs, var.concourse_egress_cidrs))
  }

  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = compact(concat(var.admin_cidrs, var.concourse_egress_cidrs))
  }

  tags = {
    Name = "${var.env}-office-access-ssh"
  }
}

