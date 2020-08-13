resource "aws_vpc" "paas" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = var.env
  }
}

