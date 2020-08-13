provider "aws" {
  version = "~>2.0"
  region  = var.region
}

provider "aws" {
  alias  = "codecommit"
  region = "us-east-1"
}

provider "random" {
  version = "~>2.3"
}

provider "template" {
  version = "2.1.2"
}
