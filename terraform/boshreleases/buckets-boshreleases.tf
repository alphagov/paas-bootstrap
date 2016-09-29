resource "aws_s3_bucket" "datadog-agent-boshrelease" {
  bucket = "gds-paas-datadog-agent-boshrelease"
  acl = "public-read"
  force_destroy = "true"
}
