resource "aws_acm_certificate" "system" {
  domain_name               = "*.${var.system_dns_zone_name}"
  subject_alternative_names = [var.system_dns_zone_name]
  validation_method         = "DNS"
}

resource "aws_route53_record" "system_cert_validation" {
  name    = tolist(aws_acm_certificate.system.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.system.domain_validation_options)[0].resource_record_type
  zone_id = var.system_dns_zone_id
  records = [tolist(aws_acm_certificate.system.domain_validation_options)[0].resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "system" {
  certificate_arn = aws_acm_certificate.system.arn

  validation_record_fqdns = [
    aws_route53_record.system_cert_validation.fqdn,
  ]
}

