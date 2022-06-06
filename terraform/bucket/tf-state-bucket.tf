variable "state_bucket" {
  description = "Name of the AWS S3 bucket used to store the state"
}

resource "aws_s3_bucket" "terraform-state-s3" {
  bucket = var.state_bucket

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_acl" "terraform-state-s3" {
  bucket = var.state_bucket
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "terraform-state-s3" {
  bucket = var.state_bucket

  versioning_configuration {
    status = "Enabled"
  }
}

