resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id            = aws_vpc.paas.id
  service_name      = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.secrets_manager_endpoint_access.id,
  ]

  subnet_ids          = aws_subnet.vpc_aws_endpoint[*].id
  private_dns_enabled = true

  tags = {
    Build       = "terraform"
    Resource    = "aws_vpc_endpoint"
    Environment = var.env
    Name        = "${var.env}-secrets-manager"
  }
}

resource "aws_security_group" "secrets_manager_endpoint_access" {
  name        = "${var.env}-secrets-manager-endpoint"
  description = "Allow HTTPS inbound traffic for security manager vpc endpoint"
  vpc_id      = aws_vpc.paas.id

  ingress {
    description = "HTTPS for security manager vpc endpoint"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Build       = "terraform"
    Resource    = "aws_security_group"
    Environment = var.env
    Name        = "${var.env}-secrets-manager-endpoint"
  }
}

resource "aws_subnet" "vpc_aws_endpoint" {
  count = length(var.aws_vpc_endpoint_cidrs_per_zone)

  vpc_id            = aws_vpc.paas.id
  cidr_block        = var.aws_vpc_endpoint_cidrs_per_zone[format("zone%d", count.index)]
  availability_zone = var.zones[format("zone%d", count.index)]

  map_public_ip_on_launch = false

  tags = {
    Build       = "terraform"
    Resource    = "aws_subnet"
    Environment = var.env
    Name        = "${var.env}-vpc-endpoint-${count.index}"
  }
}
