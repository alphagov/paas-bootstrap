terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.9.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.6.1"
    }
  }
  required_version = ">= 1.5.2"
}
