resource "aws_s3_bucket" "bosh-blobstore" {
  bucket        = "gds-paas-${var.env}-bosh-blobstore"
  force_destroy = "true"
}

resource "aws_s3_bucket_ownership_controls" "bosh-blobstore" {
  bucket = aws_s3_bucket.bosh-blobstore.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "bosh-blobstore_acl" {
  bucket = aws_s3_bucket.bosh-blobstore.id
  acl    = "private"

  depends_on = [aws_s3_bucket_ownership_controls.bosh-blobstore]
}

