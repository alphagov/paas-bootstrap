resource "aws_acm_certificate" "bosh" {
  domain_name = "bosh-external.${var.system_dns_zone_name}"

  subject_alternative_names = [
    "uaa-external.${var.system_dns_zone_name}",
  ]

  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "bosh_cert_validation" {
  count   = "${length(aws_acm_certificate.bosh.domain_validation_options)}"
  zone_id = "${var.system_dns_zone_id}"
  ttl     = 60

  name = "${lookup(
    aws_acm_certificate.bosh.domain_validation_options[count.index],
    "resource_record_name"
  )}"

  type = "${lookup(
    aws_acm_certificate.bosh.domain_validation_options[count.index],
    "resource_record_type"
  )}"

  records = ["${lookup(
    aws_acm_certificate.bosh.domain_validation_options[count.index],
    "resource_record_value"
  )}"]
}

resource "aws_acm_certificate_validation" "bosh" {
  certificate_arn         = "${aws_acm_certificate.bosh.arn}"
  validation_record_fqdns = ["${aws_route53_record.bosh_cert_validation.*.fqdn}"]
}
