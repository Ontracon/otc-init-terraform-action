terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.11"
    }
  }
  backend "local" {}
}

provider "aws" {
  region = var.cloud_region
}
