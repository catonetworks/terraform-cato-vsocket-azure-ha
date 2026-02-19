terraform {
  required_providers {
    cato = {
      source  = "catonetworks/cato"
      version = "0.0.57"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.31.0"
    }
  }
  required_version = ">= 1.5"
}
