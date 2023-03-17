terraform {
  backend "s3" {
    key = "vpc.tfstate"
  }
}
