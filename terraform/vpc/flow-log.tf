resource "aws_s3_bucket" "vpc-flow-logs" {
  bucket = "gds-paas-${var.env}-vpc-flow-logs"

  tags = {
    Environment = var.env
  }
}

resource "aws_s3_bucket_ownership_controls" "vpc-flow-logs" {
  bucket = aws_s3_bucket.vpc-flow-logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "vpc-flow-logs" {
  bucket     = aws_s3_bucket.vpc-flow-logs.id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.vpc-flow-logs]
}

resource "aws_s3_bucket_lifecycle_configuration" "vpc-flow-logs-30d" {
  bucket = aws_s3_bucket.vpc-flow-logs.id


  rule {
    id     = "Expire old logs"
    status = "Enabled"

    expiration {
      # S3 charges for a minimum period of 30 days so may as well
      # use at least 30d
      days = 30
    }
  }
}

resource "aws_flow_log" "paas" {
  log_destination      = aws_s3_bucket.vpc-flow-logs.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.paas.id
  destination_options {
    file_format        = "parquet"
    per_hour_partition = true
  }

  tags = {
    Name        = "${var.env}-all-to-parquet"
    Environment = var.env
  }
}
