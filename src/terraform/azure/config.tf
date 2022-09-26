terraform {
  required_version = ">= 0.13.1"
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}