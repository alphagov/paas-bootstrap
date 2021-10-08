resource "aws_acm_certificate" "system" {
  domain_name               = "*.${var.system_dns_zone_name}"
  subject_alternative_names = [var.system_dns_zone_name]
  validation_method         = "DNS"
}

resource "aws_route53_record" "system_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.system.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "system" {
  certificate_arn = aws_acm_certificate.system.arn

  validation_record_fqdns = [
    for record in aws_route53_record.system_cert_validation : record.fqdn
  ]
}

