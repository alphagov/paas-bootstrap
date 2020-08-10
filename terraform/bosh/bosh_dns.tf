resource "aws_route53_record" "bosh" {
  zone_id = var.system_dns_zone_id
  name    = var.bosh_fqdn
  type    = "A"
  ttl     = "60"
  records = [var.microbosh_ips[var.bosh_az]]
}

resource "aws_route53_record" "bosh-external" {
  zone_id = var.system_dns_zone_id
  name    = var.bosh_fqdn_external
  type    = "A"
  ttl     = "60"
  records = [aws_eip.bosh.public_ip]
}

