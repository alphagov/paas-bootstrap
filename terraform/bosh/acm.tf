locals {
  bosh_lb_domains = [
    "bosh-external.${var.system_dns_zone_name}",
    "bosh-uaa-external.${var.system_dns_zone_name}",
  ]

  bosh_lb_domain_name = element(local.bosh_lb_domains, 0)

  bosh_lb_sans = slice(local.bosh_lb_domains, 1, length(local.bosh_lb_domains))
}

resource "aws_acm_certificate" "bosh" {
  domain_name = "bosh-external.${var.system_dns_zone_name}"

  subject_alternative_names = local.bosh_lb_sans

  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "bosh_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.bosh.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  zone_id         = var.system_dns_zone_id
  records         = [each.value.record]
  ttl             = 60
}

resource "aws_acm_certificate_validation" "bosh" {
  certificate_arn = aws_acm_certificate.bosh.arn

  validation_record_fqdns = [
    for record in aws_route53_record.bosh_cert_validation : record.fqdn
  ]
}
