resource "aws_route53_record" "canary" {
  zone_id = "${var.system_dns_zone_id}"
  name    = "__canary.${var.system_dns_zone_name}"
  type    = "TXT"
  ttl     = "1"
  records = ["Test record for DNS resolution checks."]
}
