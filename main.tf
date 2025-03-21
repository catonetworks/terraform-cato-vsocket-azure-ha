## vSocket Module Resources
provider "azurerm" {
  features {}
}

provider "cato" {
  baseurl    = var.baseurl
  token      = var.token
  account_id = var.account_id
}

data "azurerm_network_interface" "mgmt_primary" {
  name                = var.mgmt_nic_name_primary
  resource_group_name = var.resource_group_name
}

data "azurerm_network_interface" "wan_primary" {
  name                = var.wan_nic_name_primary
  resource_group_name = var.resource_group_name
}

data "azurerm_network_interface" "lan_primary" {
  name                = var.lan_nic_name_primary
  resource_group_name = var.resource_group_name
}

data "azurerm_network_interface" "mgmt_secondary" {
  name                = var.mgmt_nic_name_secondary
  resource_group_name = var.resource_group_name
}

data "azurerm_network_interface" "wan_secondary" {
  name                = var.wan_nic_name_secondary
  resource_group_name = var.resource_group_name
}

data "azurerm_network_interface" "lan_secondary" {
  name                = var.lan_nic_name_secondary
  resource_group_name = var.resource_group_name
}

resource "cato_socket_site" "azure-site" {
  connection_type = "SOCKET_AZ1500"
  description     = var.site_description
  name            = var.site_name
  native_range = {
    native_network_range = var.lan_prefix
    local_ip             = data.azurerm_network_interface.lan_primary.private_ip_address
  }
  site_location = var.site_location
  site_type     = var.site_type
}

data "cato_accountSnapshotSite" "azure-site" {
  id = cato_socket_site.azure-site.id
}

locals {
  primary_serial = [for s in data.cato_accountSnapshotSite.azure-site.info.sockets : s.serial if s.is_primary == true]
}

# Create HA user Assigned Identity
resource "azurerm_user_assigned_identity" "CatoHaIdentity" {
  location            = var.location
  name                = "CatoHaIdentity"
  resource_group_name = var.resource_group_name
}

# Create route table and associate to lanSubnet
resource "azurerm_route_table" "route_table" {
  location                      = var.location
  name                          = "${var.site_name}-Route-Table"
  resource_group_name           = var.resource_group_name
  
  route {
      address_prefix         = "0.0.0.0/0"
      name                   = "Default_to_Cato"
      next_hop_in_ip_address = var.floating_ip
      next_hop_type          = "VirtualAppliance"
    }
}

resource "azurerm_subnet_route_table_association" "lan_subnet_association" {
  subnet_id      = data.azurerm_network_interface.lan_primary.ip_configuration[0].subnet_id
  route_table_id = azurerm_route_table.route_table.id
}

# Create Primary Vsocket Virtual Machine
resource "azurerm_virtual_machine" "vsocket_primary" {
  location                     = var.location
  name                         = "${var.site_name}-vSocket-Primary"
  network_interface_ids        = [data.azurerm_network_interface.mgmt_primary.id, data.azurerm_network_interface.wan_primary.id, data.azurerm_network_interface.lan_primary.id]
  primary_network_interface_id = data.azurerm_network_interface.mgmt_primary.id
  resource_group_name          = var.resource_group_name
  vm_size                      = var.vm_size
  plan {
    name      = "public-cato-socket"
    product   = "cato_socket"
    publisher = "catonetworks"
  }
  boot_diagnostics {
    enabled     = true
    storage_uri = ""
  }
  storage_os_disk {
    create_option     = "Attach"
    name              = "${var.site_name}-vSocket-disk-primary"
    managed_disk_id   = azurerm_managed_disk.vSocket_disk_primary.id
    os_type = "Linux"
  }

  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.CatoHaIdentity.id]
  }
  
  depends_on = [
    azurerm_managed_disk.vSocket_disk_primary
  ]
}

resource "azurerm_managed_disk" "vSocket_disk_primary" {
  name                 = "${var.site_name}-vSocket-disk-primary"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = "Standard_LRS"
  create_option        = "FromImage"
  disk_size_gb         = var.disk_size_gb
  os_type              = "Linux"
  image_reference_id   = var.image_reference_id
  lifecycle {
    ignore_changes = all
  }
}

variable "commands" {
  type    = list(string)
  default = [
    "rm /cato/deviceid.txt",
    "rm /cato/socket/configuration/socket_registration.json",
    "nohup /cato/socket/run_socket_daemon.sh &"
   ]
}

resource "azurerm_virtual_machine_extension" "vsocket-custom-script-primary" {
  auto_upgrade_minor_version = true
  name                       = "vsocket-custom-script-primary"
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.1"
  virtual_machine_id         = azurerm_virtual_machine.vsocket_primary.id
  lifecycle {
    ignore_changes = all
  }
  settings = <<SETTINGS
 {
  "commandToExecute": "${"echo '${local.primary_serial[0]}' > /cato/serial.txt"};${join(";", var.commands)}"
 }
SETTINGS
  depends_on = [
    azurerm_virtual_machine.vsocket_primary
  ]
}

#################################################################################
# Add secondary socket to site via API until socket_site resrouce is updated to natively support
resource "null_resource" "configure_secondary_azure_vsocket" {
  depends_on = [azurerm_virtual_machine_extension.vsocket-custom-script-primary]

  provisioner "local-exec" {
    command = <<EOF
      # Execute the GraphQL mutation to get the site id
      response=$(curl -k -X POST \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "x-API-Key: ${var.token}" \
        "${var.baseurl}" \
        --data '{
          "query": "mutation siteAddSecondaryAzureVSocket($accountId: ID!, $addSecondaryAzureVSocketInput: AddSecondaryAzureVSocketInput!) { site(accountId: $accountId) { addSecondaryAzureVSocket(input: $addSecondaryAzureVSocketInput) { id } } }",
          "variables": {
            "accountId": "${var.account_id}",
            "addSecondaryAzureVSocketInput": {
              "floatingIp": "${var.floating_ip}",
              "interfaceIp": "${data.azurerm_network_interface.lan_secondary.private_ip_address}",
              "site": {
                "by": "ID",
                "input": "${cato_socket_site.azure-site.id}"
              }
            }
          },
          "operationName": "siteAddSecondaryAzureVSocket"
        }' )
    EOF
  }

  triggers = {
    account_id = var.account_id
    site_id    = cato_socket_site.azure-site.id
  }
}


# Create Secondary Vsocket Virtual Machine
data "cato_accountSnapshotSite" "azure-site-secondary" {
  depends_on = [ null_resource.configure_secondary_azure_vsocket ]
  id = cato_socket_site.azure-site.id
}

locals {
  secondary_serial = [for s in data.cato_accountSnapshotSite.azure-site-secondary.info.sockets : s.serial if s.is_primary == false]
}

resource "azurerm_virtual_machine" "vsocket_secondary" {
  location                     = var.location
  name                         = "${var.site_name}-vSocket-Secondary"
  network_interface_ids        = [data.azurerm_network_interface.mgmt_secondary.id, data.azurerm_network_interface.wan_secondary.id, data.azurerm_network_interface.lan_secondary.id]
  primary_network_interface_id = data.azurerm_network_interface.mgmt_secondary.id
  resource_group_name          = var.resource_group_name
  vm_size                      = var.vm_size
  plan {
    name      = "public-cato-socket"
    product   = "cato_socket"
    publisher = "catonetworks"
  }
  boot_diagnostics {
    enabled     = true
    storage_uri = ""
  }
  storage_os_disk {
    create_option     = "Attach"
    name              = "${var.site_name}-vSocket-disk-secondary"
    managed_disk_id   = azurerm_managed_disk.vSocket_disk_secondary.id
    os_type = "Linux"
  }

  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.CatoHaIdentity.id]
  }
  
  depends_on = [
    azurerm_managed_disk.vSocket_disk_secondary
  ]
}

resource "azurerm_managed_disk" "vSocket_disk_secondary" {
  depends_on = [ data.cato_accountSnapshotSite.azure-site-secondary ]
  name                 = "${var.site_name}-vSocket-disk-secondary"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = "Standard_LRS"
  create_option        = "FromImage"
  disk_size_gb         = var.disk_size_gb
  os_type              = "Linux"
  image_reference_id   = var.image_reference_id
  lifecycle {
    ignore_changes = all
  }
}

variable "commands-secondary" {
  type    = list(string)
  default = [
    "rm /cato/deviceid.txt",
    "rm /cato/socket/configuration/socket_registration.json",
    "nohup /cato/socket/run_socket_daemon.sh &"
   ]
}

resource "azurerm_virtual_machine_extension" "vsocket-custom-script-secondary" {
  auto_upgrade_minor_version = true
  name                       = "vsocket-custom-script-secondary"
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.1"
  virtual_machine_id         = azurerm_virtual_machine.vsocket_secondary.id
  lifecycle {
    ignore_changes = all
  }
  settings = <<SETTINGS
 {
  "commandToExecute": "${"echo '${local.secondary_serial[0]}' > /cato/serial.txt"};${join(";", var.commands-secondary)}"
 }
SETTINGS
  depends_on = [
    azurerm_virtual_machine.vsocket_secondary
  ]
}

# Create HA Settings Secondary
resource "null_resource" "run_command_ha_primary" {
  provisioner "local-exec" {
    command = <<EOT
      az vm run-command invoke \
        --resource-group ${var.resource_group_name} \
        --name "${var.site_name}-vSocket-Primary" \
        --command-id RunShellScript \
        --scripts "echo '{\"location\": \"${var.location}\", \"subscription_id\": \"${var.azure_subscription_id}\", \"vnet\": \"${var.vnet_name}\", \"group\": \"${var.resource_group_name}\", \"vnet_group\": \"${var.resource_group_name}\", \"subnet\": \"${var.lan_subnet_name}\", \"nic\": \"${data.azurerm_network_interface.lan_primary.name}\", \"ha_nic\": \"${data.azurerm_network_interface.lan_secondary.name}\", \"lan_nic_ip\": \"${data.azurerm_network_interface.lan_primary.private_ip_address}\", \"lan_nic_mac\": \"${data.azurerm_network_interface.lan_primary.mac_address}\", \"subnet_cidr\": \"${var.lan_prefix}\", \"az_mgmt_url\": \"management.azure.com\"}' > /cato/socket/configuration/vm_config.json"
    EOT
  }

  depends_on = [
    azurerm_virtual_machine_extension.vsocket-custom-script-secondary
  ]
}

resource "null_resource" "run_command_ha_secondary" {
  provisioner "local-exec" {
    command = <<EOT
      az vm run-command invoke \
        --resource-group ${var.resource_group_name} \
        --name "${var.site_name}-vSocket-Secondary" \
        --command-id RunShellScript \
        --scripts "echo '{\"location\": \"${var.location}\", \"subscription_id\": \"${var.azure_subscription_id}\", \"vnet\": \"${var.vnet_name}\", \"group\": \"${var.resource_group_name}\", \"vnet_group\": \"${var.resource_group_name}\", \"subnet\": \"${var.lan_subnet_name}\", \"nic\": \"${data.azurerm_network_interface.lan_secondary.name}\", \"ha_nic\": \"${data.azurerm_network_interface.lan_primary.name}\", \"lan_nic_ip\": \"${data.azurerm_network_interface.lan_secondary.private_ip_address}\", \"lan_nic_mac\": \"${data.azurerm_network_interface.lan_secondary.mac_address}\", \"subnet_cidr\": \"${var.lan_prefix}\", \"az_mgmt_url\": \"management.azure.com\"}' > /cato/socket/configuration/vm_config.json"
    EOT
  }

  depends_on = [
    azurerm_virtual_machine_extension.vsocket-custom-script-secondary
  ]
}


# Collect MAC addess of Secondary LAN interface
output "lan-sec-mac" {
  value = data.azurerm_network_interface.lan_secondary.mac_address
}

# Role assignments for secondary lan nic and subnet
resource "azurerm_role_assignment" "secondary_nic_ha_role" {
  principal_id = azurerm_user_assigned_identity.CatoHaIdentity.principal_id
  role_definition_name = "Virtual Machine Contributor"
  scope = "${data.azurerm_network_interface.lan_secondary.id}"
  depends_on = [ azurerm_virtual_machine.vsocket_secondary ]
}

resource "azurerm_role_assignment" "lan-subnet-role" {
  principal_id = azurerm_user_assigned_identity.CatoHaIdentity.principal_id
  role_definition_name = "Virtual Machine Contributor"
  scope = "/subscriptions/${var.azure_subscription_id}/resourcegroups/${var.resource_group_name}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.lan_subnet_name}"
  depends_on = [ azurerm_user_assigned_identity.CatoHaIdentity ]
}

#Temporary role assignments for primary
resource "azurerm_role_assignment" "primary_nic_ha_role" {
  principal_id = azurerm_user_assigned_identity.CatoHaIdentity.principal_id
  role_definition_name = "Virtual Machine Contributor"
  scope = "/subscriptions/${var.azure_subscription_id}/resourcegroups/${var.resource_group_name}/providers/Microsoft.Network/networkInterfaces/${data.azurerm_network_interface.lan_primary.name}"
  depends_on = [ azurerm_user_assigned_identity.CatoHaIdentity ]
}


# Time delay to allow for vsockets to upgrade
resource "null_resource" "delay" {
  depends_on = [ null_resource.run_command_ha_secondary ]
  provisioner "local-exec" {
    command = "sleep 10"
  }
}

# Reboot both vsockets
resource "null_resource" "reboot_vsocket_primary" {
  provisioner "local-exec" {
    command = <<EOT
      az vm restart --resource-group "${var.resource_group_name}" --name "${var.site_name}-vSocket-Primary"
    EOT
  }

  depends_on = [
    null_resource.run_command_ha_secondary
  ]
}

resource "null_resource" "reboot_vsocket_secondary" {
  provisioner "local-exec" {
    command = <<EOT
      az vm restart --resource-group "${var.resource_group_name}" --name "${var.site_name}-vSocket-Secondary"
    EOT
  }

  depends_on = [
    null_resource.run_command_ha_secondary
  ]
}
