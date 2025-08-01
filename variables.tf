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
  description = "Site location which is used by the Cato Socket to connect to the closest Cato PoP. If not specified, the location will be derived from the Azure region dynamicaly."
  type = object({
    city         = string
    country_code = string
    state_code   = string
    timezone     = string
  })
  default = {
    city         = null
    country_code = null
    state_code   = null ## Optional - for countries with states
    timezone     = null
  }
}

variable "native_network_range" {
  type        = string
  description = <<EOT
  	Choose a unique range for your Azure environment that does not conflict with the rest of your Wide Area Network.
    The accepted input format is Standard CIDR Notation, e.g. X.X.X.X/X
	EOT
}

variable "subnet_range_lan" {
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
}

variable "resource_group_name" {
  description = "(Required) The name of the Azure Resource Group where all resources will be created."
  type        = string
}

variable "mgmt_nic_name_primary" {
  description = "The name of the primary management network interface."
  type        = string
}

variable "wan_nic_name_primary" {
  description = "The name of the primary WAN network interface."
  type        = string
}

variable "lan_nic_name_primary" {
  description = "The name of the primary LAN network interface."
  type        = string
}

variable "mgmt_nic_name_secondary" {
  description = "The name of the secondary management network interface."
  type        = string
}

variable "wan_nic_name_secondary" {
  description = "The name of the secondary WAN network interface."
  type        = string
}

variable "lan_nic_name_secondary" {
  description = "The name of the secondary LAN network interface."
  type        = string
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

variable "dns_servers" {
  type = list(string)
  default = [
    "10.254.254.1",  # Cato Cloud DNS
    "168.63.129.16", # Azure DNS
    "1.1.1.1",
    "8.8.8.8"
  ]
}

variable "license_id" {
  description = "The license ID for the Cato vSocket of license type CATO_SITE, CATO_SSE_SITE, CATO_PB, CATO_PB_SSE.  Example License ID value: 'abcde123-abcd-1234-abcd-abcde1234567'.  Note that licenses are for commercial accounts, and not supported for trial accounts."
  type        = string
  default     = null
}

variable "license_bw" {
  description = "The license bandwidth number for the cato site, specifying bandwidth ONLY applies for pooled licenses.  For a standard site license that is not pooled, leave this value null. Must be a number greater than 0 and an increment of 10."
  type        = string
  default     = null
}

variable "tags" {
  description = "A Map of Key = Value to describe infrastructure"
  type        = map(any)
  default     = null
}

variable "enable_static_range_translation" {
  description = "Enables the ability to use translated ranges"
  type        = string
  default     = false
}

variable "routed_networks" {
  description = <<EOF
  A map of routed networks to be accessed behind the vSocket site.
  - The key is the logical name for the network.
  - The value is an object containing:
    - "subnet" (string, required): The actual CIDR range of the network.
    - "translated_subnet" (string, optional): The NATed CIDR range if translation is used.
  Example: 
  routed_networks = {
    "Peered-VNET-1" = {
      subnet = "10.100.1.0/24"
    }
    "On-Prem-Network-NAT" = {
      subnet            = "192.168.51.0/24"
      translated_subnet = "10.200.1.0/24"
    }
  }
  EOF
  type = map(object({
    subnet            = string
    translated_subnet = optional(string)
    gateway           = optional(string)
    interface_index   = optional(string, "LAN1")
  }))
  default = {}
}

variable "commands" {
  type = list(string)
  default = [
    "rm /cato/deviceid.txt",
    "rm /cato/socket/configuration/socket_registration.json",
    "nohup /cato/socket/run_socket_daemon.sh &"
  ]
}