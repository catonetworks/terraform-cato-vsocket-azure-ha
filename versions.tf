terraform {
  required_providers {
    cato = {
      source = "catonetworks/cato"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
  required_version = ">= 0.13"
}
