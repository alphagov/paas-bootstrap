resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.paas.id
}

resource "aws_route_table" "infra" {
  vpc_id = aws_vpc.paas.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }
}

resource "aws_subnet" "infra" {
  count             = var.zone_count
  vpc_id            = aws_vpc.paas.id
  cidr_block        = var.infra_cidrs[format("zone%d", count.index)]
  availability_zone = var.zones[format("zone%d", count.index)]
  depends_on        = [aws_internet_gateway.default]

  tags = {
    Name = "${var.env}-infra-${var.zones[format("zone%d", count.index)]}"
  }
}

resource "aws_route_table_association" "infra" {
  count          = var.zone_count
  subnet_id      = element(aws_subnet.infra.*.id, count.index)
  route_table_id = aws_route_table.infra.id
}

