terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.6.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.4.3"
    }
  }
  required_version = ">= 1.3.3"
}
