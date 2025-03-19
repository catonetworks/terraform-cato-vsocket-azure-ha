## vSocket Module Variables

variable "token" {
  description = "API token used to authenticate with the Cato Networks API."
}

variable "account_id" {
  description = "Account ID used for the Cato Networks integration."
  type        = number
  default     = null
}

variable "baseurl" {
  description = "Base URL for the Cato Networks API."
  type        = string
  default     = "https://api.catonetworks.com/api/v1/graphql2"
}

variable "site_description" {
  description = "A brief description of the site for identification purposes."
  type        = string
}

variable "site_type" {
  description = "The type of the site (DATACENTER, BRANCH, CLOUD_DC, HEADQUARTERS)."
  type        = string
  default     = "CLOUD_DC"
  validation {
    condition     = contains(["DATACENTER", "BRANCH", "CLOUD_DC", "HEADQUARTERS"], var.site_type)
    error_message = "The site_type variable must be one of 'DATACENTER','BRANCH','CLOUD_DC','HEADQUARTERS'."
  }
}

variable "site_name" {
  description = "The name of the Cato Networks site."
  type        = string
  default     = null
}

variable "site_location" {
  description = "The physical location of the site, including city, country code, state code, and timezone."
  type = object({
    city         = string
    country_code = string
    state_code   = string
    timezone     = string
  })
  default = {
    city         = "New York"
    country_code = "US"
    state_code   = "US-NY" ## Optional - for countries with states
    timezone     = "America/New_York"
  }
}

variable "lan_prefix" {
  description = "LAN subnet prefix in CIDR notation (e.g., X.X.X.X/X)."
  type        = string
}

variable "vm_size" {
  description = "(Required) Specifies the size of the Virtual Machine. See Azure VM Naming Conventions: https://learn.microsoft.com/en-us/azure/virtual-machines/vm-naming-conventions"
  type        = string
  default     = "Standard_D8ls_v5"
}

variable "disk_size_gb" {
  description = "Size of the managed disk in GB."
  type        = number
  default     = 8
  validation {
    condition     = var.disk_size_gb > 0
    error_message = "Disk size must be greater than 0."
  }
}

## VSocket Params

variable "location" {
  description = "(Required) The Azure region where the resources should be deployed."
  type        = string
  default     = null
}

variable "resource_group_name" {
  description = "(Required) The name of the Azure Resource Group where all resources will be created."
  type        = string
  default     = null
}

variable "mgmt_nic_name_primary" {
  description = "The name of the primary management network interface."
  type        = string
  default     = null
}

variable "wan_nic_name_primary" {
  description = "The name of the primary WAN network interface."
  type        = string
  default     = null
}

variable "lan_nic_name_primary" {
  description = "The name of the primary LAN network interface."
  type        = string
  default     = null
}

variable "mgmt_nic_name_secondary" {
  description = "The name of the secondary management network interface."
  type        = string
  default     = null
}

variable "wan_nic_name_secondary" {
  description = "The name of the secondary WAN network interface."
  type        = string
  default     = null
}

variable "lan_nic_name_secondary" {
  description = "The name of the secondary LAN network interface."
  type        = string
  default     = null
}

variable "floating_ip" {
  description = "The floating IP address used for High Availability (HA) failover."
  type        = string
}

variable "image_reference_id" {
  description = "The path to the image used to deploy a specific version of the virtual socket."
  type        = string
  default     = "/Subscriptions/38b5ec1d-b3b6-4f50-a34e-f04a67121955/Providers/Microsoft.Compute/Locations/eastus/Publishers/catonetworks/ArtifactTypes/VMImage/Offers/cato_socket/Skus/public-cato-socket/Versions/19.0.17805"
}

variable "azure_subscription_id" {
  description = "The Azure Subscription ID where the resources will be created."
  type        = string
}

variable "vnet_name" {
  description = "The name of the Virtual Network (VNET) where the vSockets will be deployed."
  type        = string
}

variable "lan_subnet_name" {
  description = "The name of the LAN subnet within the specified VNET."
  type        = string
}