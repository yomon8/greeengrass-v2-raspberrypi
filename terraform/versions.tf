terraform {
  required_providers {
    aws = {
      version = "= 4.53.0"
      source  = "hashicorp/aws"
    }
  }
  backend "s3" {
  }
}

provider "aws" {
  profile = var.profile
  region  = var.region
  default_tags {
    tags = {
      GG_DEVICE = var.device_name
    }
  }
}
