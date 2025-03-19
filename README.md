# CATO VSOCKET Azure VNET Terraform module

Terraform module which creates an Azure Socket Site in the Cato Management Application (CMA), and deploys a pair of HA virtual socket instances in Azure.

List of resources:
- azurerm_managed_disk (vSocket_disk_primary)
- azurerm_managed_disk (vSocket_disk_secondary)
- azurerm_role_assignment (lan-subnet-role)
- azurerm_role_assignment (primary_nic_ha_role)
- azurerm_role_assignment (secondary_nic_ha_role)
- azurerm_user_assigned_identity (CatoHaIdentity)
- azurerm_virtual_machine_extension (vsocket-custom-script-primary)
- azurerm_virtual_machine_extension (vsocket-custom-script-secondary)
- azurerm_virtual_machine (vsocket_primary)
- azurerm_virtual_machine (vsocket_secondary)
- cato_socket_site (azure-site)


## Usage

```hcl
module "vsocket-azure-vnet-ha" {
  source                  = "catonetworks/vsocket-azure-vnet-ha/cato"
  token                   = "xxxxxxx"
  account_id              = "xxxxxxx"
  location                = "East US"
  resource_group_name     = "Your Resource Group Name Here"
  mgmt_nic_name_primary   = "mgmt-nic-primary"
  wan_nic_name_primary    = "wan-nic-primary"
  lan_nic_name_primary    = "lan-nic-primary"
  mgmt_nic_name_secondary = "mgmt-nic-secondary"
  wan_nic_name_secondary  = "wan-nic-secondary"
  lan_nic_name_secondary  = "lan-nic-secondary"
  floating_ip             = "10.3.3.6"
  lan_prefix              = "10.3.3.0/24"
  azure_subscription_id   = "1234abcd-abcd-abcd-1234-abcde12345"
  vnet_name               = "Your VNET Name HERE"
  lan_subnet_name         = "Azure_Socket_Site_subnetLAN"
  site_name               = "Azure_Socket_Site"
  site_description        = "Azure Socket Site East US"
  site_type               = "CLOUD_DC"
  site_location = {
    city         = "New York"
    country_code = "US"
    state_code   = "US-NY" ## Optional - for coutnries with states
    timezone     = "America/New_York"
  }
}
```

## Site Location Reference

For more information on site_location syntax, use the [Cato CLI](https://github.com/catonetworks/cato-cli) to lookup values.

```bash
$ pip3 install catocli
$ export CATO_TOKEN="your-api-token-here"
$ export CATO_ACCOUNT_ID="your-account-id"
$ catocli query siteLocation -h
$ catocli query siteLocation '{"filters":[{"search": "San Diego","field":"city","operation":"exact"}]}' -p
```

## Authors

Module is maintained by [Cato Networks](https://github.com/catonetworks) with help from [these awesome contributors](https://github.com/catonetworks/terraform-cato-vsocket-azure-vnet/graphs/contributors).

## License

Apache 2 Licensed. See [LICENSE](https://github.com/catonetworks/terraform-cato-vsocket-azure-vnet/tree/master/LICENSE) for full details.

