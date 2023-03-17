terraform {
  backend "s3" {
    key = "bosh.tfstate"
  }
}
