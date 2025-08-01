
## Create random strings for auth, as a socket does not allow auth but the instance requires it
resource "random_string" "vsocket-random-username" {
  length  = 16
  special = false
}

resource "random_string" "vsocket-random-password" {
  length  = 16
  special = false
  upper   = true
  lower   = true
  numeric = true
}

## vSocket Module Resources
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
    native_network_range = var.native_network_range
    local_ip             = data.azurerm_network_interface.lan_primary.private_ip_address
  }
  site_location = local.cur_site_location
  site_type     = var.site_type

  lifecycle {
    ignore_changes = [native_range.local_ip] #Floating IP expected to Change depending on Active Config
  }
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
  name                = "${var.site_name}-CatoHaIdentity" ###Needing to be unique add ${sitename}-
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Create Primary Vsocket Virtual Machine
resource "azurerm_linux_virtual_machine" "vsocket_primary" {
  location            = var.location
  name                = "${var.site_name}-vSocket-Primary"
  computer_name       = replace("${var.site_name}-vSocket-Primary", "/[\\\\/\\[\\]:|<>+=;,?*@&~!#$%^()_{}' ]/", "-")
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  network_interface_ids = [
    data.azurerm_network_interface.mgmt_primary.id,
    data.azurerm_network_interface.wan_primary.id,
    data.azurerm_network_interface.lan_primary.id
  ]
  disable_password_authentication = false
  provision_vm_agent              = true
  allow_extension_operations      = true
  admin_username                  = random_string.vsocket-random-username.result
  admin_password                  = "${random_string.vsocket-random-password.result}@"

  # Boot diagnostics
  boot_diagnostics {
    storage_account_uri = "" # Empty string enables boot diagnostics
  }

  # Assign CatoHaIdentity to the Vsocket
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.CatoHaIdentity.id]
  }

  # OS disk configuration from image
  os_disk {
    name                 = "${var.site_name}-vSocket-disk-primary"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 8
  }

  plan {
    name      = "public-cato-socket"
    publisher = "catonetworks"
    product   = "cato_socket"
  }

  source_image_reference {
    publisher = "catonetworks"
    offer     = "cato_socket"
    sku       = "public-cato-socket"
    version   = "23.0.19605"
  }

  depends_on = [
    data.cato_accountSnapshotSite.azure-site-2
  ]
  tags = var.tags
}

# To allow mac address to be retrieved
resource "time_sleep" "sleep_5_seconds" {
  create_duration = "5s"
  depends_on      = [azurerm_linux_virtual_machine.vsocket_primary]
}

data "azurerm_network_interface" "wan_mac_primary" {
  name                = var.wan_nic_name_primary
  resource_group_name = var.resource_group_name
  depends_on          = [time_sleep.sleep_5_seconds]
}

data "azurerm_network_interface" "lan_mac_primary" {
  name                = var.lan_nic_name_primary
  resource_group_name = var.resource_group_name
  depends_on          = [time_sleep.sleep_5_seconds]
}

resource "azurerm_virtual_machine_extension" "vsocket-custom-script-primary" {
  auto_upgrade_minor_version = true
  name                       = "vsocket-custom-script-primary"
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.1"
  virtual_machine_id         = azurerm_linux_virtual_machine.vsocket_primary.id
  lifecycle {
    ignore_changes = all
  }
  settings = <<SETTINGS
  {
  "commandToExecute": "echo '{\"wan_ip\" : \"${data.azurerm_network_interface.wan_primary.private_ip_address}\", \"wan_name\" : \"${data.azurerm_network_interface.wan_primary.name}\", \"wan_nic_mac\" : \"${lower(replace(data.azurerm_network_interface.wan_mac_primary.mac_address, "-", ":"))}\", \"lan_ip\" : \"${data.azurerm_network_interface.lan_primary.private_ip_address}\", \"lan_name\" : \"${data.azurerm_network_interface.lan_primary.name}\", \"lan_nic_mac\" : \"${lower(replace(data.azurerm_network_interface.lan_mac_primary.mac_address, "-", ":"))}\"}' > /cato/nics_config.json; echo '${local.primary_serial[0]}' > /cato/serial.txt;${join(";", var.commands)}"
  }
SETTINGS
  depends_on = [
    azurerm_linux_virtual_machine.vsocket_primary,
    data.azurerm_network_interface.mgmt_primary,
    data.azurerm_network_interface.wan_primary,
    data.azurerm_network_interface.lan_primary,
    data.azurerm_network_interface.lan_mac_primary,
    data.azurerm_network_interface.wan_mac_primary
  ]
}

# Time delay to allow for vsockets to upgrade
resource "null_resource" "delay-300" {
  depends_on = [azurerm_virtual_machine_extension.vsocket-custom-script-primary]
  provisioner "local-exec" {
    command = "sleep 300"
  }
}

#################################################################################
# Add secondary socket to site via API until socket_site resrouce is updated to natively support
resource "null_resource" "configure_secondary_azure_vsocket" {
  depends_on = [null_resource.delay-300]

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

# Sleep to allow Secondary vSocket serial retrieval
resource "null_resource" "sleep_30_seconds" {
  provisioner "local-exec" {
    command = "sleep 30"
  }
  depends_on = [null_resource.configure_secondary_azure_vsocket]
}

# Create Secondary Vsocket Virtual Machine
data "cato_accountSnapshotSite" "azure-site-secondary" {
  depends_on = [null_resource.sleep_30_seconds]
  id         = cato_socket_site.azure-site.id
}

locals {
  secondary_serial = [for s in data.cato_accountSnapshotSite.azure-site-secondary.info.sockets : s.serial if s.is_primary == false]
}

resource "azurerm_linux_virtual_machine" "vsocket_secondary" {
  location            = var.location
  name                = "${var.site_name}-vSocket-Secondary"
  computer_name       = replace("${var.site_name}-vSocket-Secondary", "/[\\\\/\\[\\]:|<>+=;,?*@&~!#$%^()_{}' ]/", "-")
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  network_interface_ids = [
    data.azurerm_network_interface.mgmt_secondary.id,
    data.azurerm_network_interface.wan_secondary.id,
    data.azurerm_network_interface.lan_secondary.id
  ]
  disable_password_authentication = false
  provision_vm_agent              = true
  allow_extension_operations      = true
  admin_username                  = random_string.vsocket-random-username.result
  admin_password                  = "${random_string.vsocket-random-password.result}@"

  # Boot diagnostics
  boot_diagnostics {
    storage_account_uri = "" # Empty string enables boot diagnostics
  }

  # Assign CatoHaIdentity to the Vsocket
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.CatoHaIdentity.id]
  }

  # OS disk configuration from image
  os_disk {
    name                 = "${var.site_name}-vSocket-disk-secondary"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 8
  }

  plan {
    name      = "public-cato-socket"
    publisher = "catonetworks"
    product   = "cato_socket"
  }

  source_image_reference {
    publisher = "catonetworks"
    offer     = "cato_socket"
    sku       = "public-cato-socket"
    version   = "23.0.19605"
  }

  depends_on = [
    data.cato_accountSnapshotSite.azure-site-secondary
  ]
  tags = var.tags
}

# To allow mac address to be retrieved
resource "time_sleep" "sleep_5_seconds_secondary" {
  create_duration = "5s"
  depends_on      = [azurerm_linux_virtual_machine.vsocket_secondary]
}

data "azurerm_network_interface" "wan_mac_secondary" {
  name                = var.wan_nic_name_secondary
  resource_group_name = var.resource_group_name
  depends_on          = [time_sleep.sleep_5_seconds_secondary]
}

data "azurerm_network_interface" "lan_mac_secondary" {
  name                = var.lan_nic_name_secondary
  resource_group_name = var.resource_group_name
  depends_on          = [time_sleep.sleep_5_seconds_secondary]
}

variable "commands-secondary" {
  type = list(string)
  default = [
    "nohup /cato/socket/run_socket_daemon.sh &"
  ]
}

resource "azurerm_virtual_machine_extension" "vsocket-custom-script-secondary" {
  auto_upgrade_minor_version = true
  name                       = "vsocket-custom-script-secondary"
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.1"
  virtual_machine_id         = azurerm_linux_virtual_machine.vsocket_secondary.id
  lifecycle {
    ignore_changes = all
  }

  settings = <<SETTINGS
  {
  "commandToExecute": "echo '{\"wan_ip\" : \"${data.azurerm_network_interface.wan_secondary.private_ip_address}\", \"wan_name\" : \"${data.azurerm_network_interface.wan_secondary.name}\", \"wan_nic_mac\" : \"${lower(replace(data.azurerm_network_interface.wan_mac_secondary.mac_address, "-", ":"))}\", \"lan_ip\" : \"${data.azurerm_network_interface.lan_secondary.private_ip_address}\", \"lan_name\" : \"${data.azurerm_network_interface.lan_secondary.name}\", \"lan_nic_mac\" : \"${lower(replace(data.azurerm_network_interface.lan_mac_secondary.mac_address, "-", ":"))}\"}' > /cato/nics_config.json; echo '${local.secondary_serial[0]}' > /cato/serial.txt;${join(";", var.commands)}"
  }
  SETTINGS
  depends_on = [
    azurerm_linux_virtual_machine.vsocket_secondary,
    data.azurerm_network_interface.mgmt_secondary,
    data.azurerm_network_interface.wan_secondary,
    data.azurerm_network_interface.lan_secondary,
    data.azurerm_network_interface.wan_mac_secondary,
    data.azurerm_network_interface.lan_mac_secondary
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
        --scripts "echo '{\"location\": \"${var.location}\", \"subscription_id\": \"${var.azure_subscription_id}\", \"vnet\": \"${var.vnet_name}\", \"group\": \"${var.resource_group_name}\", \"vnet_group\": \"${var.resource_group_name}\", \"subnet\": \"${var.lan_subnet_name}\", \"nic\": \"${data.azurerm_network_interface.lan_primary.name}\", \"ha_nic\": \"${data.azurerm_network_interface.lan_secondary.name}\", \"lan_nic_ip\": \"${data.azurerm_network_interface.lan_primary.private_ip_address}\", \"lan_nic_mac\": \"${data.azurerm_network_interface.lan_primary.mac_address}\", \"subnet_cidr\": \"${var.subnet_range_lan}\", \"az_mgmt_url\": \"management.azure.com\"}' > /cato/socket/configuration/vm_config.json"
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
        --scripts "echo '{\"location\": \"${var.location}\", \"subscription_id\": \"${var.azure_subscription_id}\", \"vnet\": \"${var.vnet_name}\", \"group\": \"${var.resource_group_name}\", \"vnet_group\": \"${var.resource_group_name}\", \"subnet\": \"${var.lan_subnet_name}\", \"nic\": \"${data.azurerm_network_interface.lan_secondary.name}\", \"ha_nic\": \"${data.azurerm_network_interface.lan_primary.name}\", \"lan_nic_ip\": \"${data.azurerm_network_interface.lan_secondary.private_ip_address}\", \"lan_nic_mac\": \"${data.azurerm_network_interface.lan_secondary.mac_address}\", \"subnet_cidr\": \"${var.subnet_range_lan}\", \"az_mgmt_url\": \"management.azure.com\"}' > /cato/socket/configuration/vm_config.json"
    EOT
  }

  depends_on = [
    azurerm_virtual_machine_extension.vsocket-custom-script-secondary
  ]
}

# Role assignments for secondary lan nic and subnet
resource "azurerm_role_assignment" "secondary_nic_ha_role" {
  principal_id         = azurerm_user_assigned_identity.CatoHaIdentity.principal_id
  role_definition_name = "Virtual Machine Contributor"
  scope                = data.azurerm_network_interface.lan_secondary.id
  depends_on           = [azurerm_linux_virtual_machine.vsocket_secondary]
  lifecycle {
    ignore_changes = [scope]
  }
}

resource "azurerm_role_assignment" "lan-subnet-role" {
  principal_id         = azurerm_user_assigned_identity.CatoHaIdentity.principal_id
  role_definition_name = "Virtual Machine Contributor"
  scope                = "/subscriptions/${var.azure_subscription_id}/resourcegroups/${var.resource_group_name}/providers/Microsoft.Network/virtualNetworks/${var.vnet_name}/subnets/${var.lan_subnet_name}"
  depends_on           = [azurerm_user_assigned_identity.CatoHaIdentity]
}

resource "azurerm_role_assignment" "primary_nic_ha_role" {
  principal_id         = azurerm_user_assigned_identity.CatoHaIdentity.principal_id
  role_definition_name = "Virtual Machine Contributor"
  scope                = data.azurerm_network_interface.lan_primary.id
  depends_on           = [azurerm_user_assigned_identity.CatoHaIdentity]
}

# Time delay to allow for vsockets to upgrade
resource "null_resource" "delay" {
  depends_on = [null_resource.run_command_ha_secondary]
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

# Allow vSocket to be disconnected to delete site
resource "null_resource" "sleep_before_delete" {
  provisioner "local-exec" {
    when    = destroy
    command = "sleep 10"
  }
}

data "cato_accountSnapshotSite" "azure-site-2" {
  id         = cato_socket_site.azure-site.id
  depends_on = [null_resource.sleep_before_delete]
}


resource "cato_license" "license" {
  depends_on = [null_resource.reboot_vsocket_secondary]
  count      = var.license_id == null ? 0 : 1
  site_id    = cato_socket_site.azure-site.id
  license_id = var.license_id
  bw         = var.license_bw == null ? null : var.license_bw
}

resource "cato_network_range" "routedAzure" {
  for_each        = var.routed_networks
  site_id         = cato_socket_site.azure-site.id
  name            = each.key
  range_type      = "Routed"
  gateway         = lookup(each.value.gateway, local.lan_first_ip)
  interface_index = each.value.interface_index
  # Access attributes from the value object
  subnet            = each.value.subnet
  translated_subnet = var.enable_static_range_translation ? coalesce(each.value.translated_subnet, each.value.subnet) : null
  # This will be null if not defined, and the provider will ignore it.
}
