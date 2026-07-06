###########################
## Azure Provider - Main ##
###########################

# Define Terraform provider
terraform {
  #required_version = ">= 1.1"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
  }
}

# Configure the Azure provider
provider "azurerm" {
  features {}

  environment = "public"


  subscription_id = var.azure-subscription-id != "" ? var.azure-subscription-id : null
  client_id       = var.azure-client-id != "" ? var.azure-client-id : null
  client_secret   = var.azure-client-secret != "" ? var.azure-client-secret : null
  tenant_id       = var.azure-tenant-id != "" ? var.azure-tenant-id : null
}
