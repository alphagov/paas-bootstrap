output "environment" {
  value = var.env
}

output "region" {
  value = var.region
}

output "vpc_cidr" {
  value = aws_vpc.paas.cidr_block
}

output "ssh_security_group" {
  value = aws_security_group.office-access-ssh.name
}

output "vpc_id" {
  value = aws_vpc.paas.id
}

output "subnet0_id" {
  value = element(aws_subnet.infra.*.id, 0)
}

output "subnet1_id" {
  value = element(aws_subnet.infra.*.id, 1)
}

output "subnet2_id" {
  value = element(aws_subnet.infra.*.id, 2)
}

output "zone0" {
  value = var.zones["zone0"]
}

output "zone1" {
  value = var.zones["zone1"]
}

output "zone2" {
  value = var.zones["zone2"]
}

output "infra_subnet_ids" {
  value = join(",", aws_subnet.infra.*.id)
}

output "vpc_endpoints_ip_range_zone0" {
  value = "${cidrhost(var.aws_vpc_endpoint_cidrs_per_zone.zone0, 0)}-${cidrhost(var.aws_vpc_endpoint_cidrs_per_zone.zone0, -1)}"
}

output "vpc_endpoints_ip_range_zone1" {
  value = "${cidrhost(var.aws_vpc_endpoint_cidrs_per_zone.zone1, 0)}-${cidrhost(var.aws_vpc_endpoint_cidrs_per_zone.zone1, -1)}"
}

output "vpc_endpoints_ip_range_zone2" {
  value = "${cidrhost(var.aws_vpc_endpoint_cidrs_per_zone.zone2, 0)}-${cidrhost(var.aws_vpc_endpoint_cidrs_per_zone.zone2, -1)}"
}
