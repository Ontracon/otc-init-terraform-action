terraform {
  required_version = ">= 1.0"
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.11"
    }
  }
}
provider "aws" {
  region = var.cloud_region
}
