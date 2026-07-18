terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.20"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.2"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

provider "azurerm" {
  features {}

  # subscription_id can also be supplied via ARM_SUBSCRIPTION_ID env var.
  subscription_id = var.subscription_id
}

provider "azapi" {
  # Uses the same Azure CLI / env credentials as azurerm.
}
