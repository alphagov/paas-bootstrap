variable "state_bucket" {
  description = "Name of the AWS S3 bucket used to store the state"
}

resource "aws_s3_bucket" "terraform-state-s3" {
  bucket        = var.state_bucket
  acl           = "private"
  force_destroy = "true"

  versioning {
    enabled = true
  }
}

