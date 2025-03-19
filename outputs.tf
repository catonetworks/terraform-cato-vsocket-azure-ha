# ##The following attributes are exported:

# Cato Socket Site Outputs
output "cato_site_id" {
  description = "ID of the Cato Socket Site"
  value       = cato_socket_site.azure-site.id
}

output "cato_site_name" {
  description = "Name of the Cato Site"
  value       = cato_socket_site.azure-site.name
}

output "cato_primary_serial" {
  description = "Primary Cato Socket Serial Number"
  value       = try(local.primary_serial[0], "N/A")
}

output "cato_secondary_serial" {
  description = "Secondary Cato Socket Serial Number"
  value       = try(local.secondary_serial[0], "N/A")
}

# Network Interfaces Outputs
output "mgmt_primary_nic_id" {
  description = "ID of the Management Primary Network Interface"
  value       = data.azurerm_network_interface.mgmt_primary.id
}

output "wan_primary_nic_id" {
  description = "ID of the WAN Primary Network Interface"
  value       = data.azurerm_network_interface.wan_primary.id
}

output "lan_primary_nic_id" {
  description = "ID of the LAN Primary Network Interface"
  value       = data.azurerm_network_interface.lan_primary.id
}

output "mgmt_secondary_nic_id" {
  description = "ID of the Management Secondary Network Interface"
  value       = data.azurerm_network_interface.mgmt_secondary.id
}

output "wan_secondary_nic_id" {
  description = "ID of the WAN Secondary Network Interface"
  value       = data.azurerm_network_interface.wan_secondary.id
}

output "lan_secondary_nic_id" {
  description = "ID of the LAN Secondary Network Interface"
  value       = data.azurerm_network_interface.lan_secondary.id
}

# Virtual Machine Outputs
output "vsocket_primary_vm_id" {
  description = "ID of the Primary vSocket Virtual Machine"
  value       = azurerm_virtual_machine.vsocket_primary.id
}

output "vsocket_primary_vm_name" {
  description = "Name of the Primary vSocket Virtual Machine"
  value       = azurerm_virtual_machine.vsocket_primary.name
}

output "vsocket_secondary_vm_id" {
  description = "ID of the Secondary vSocket Virtual Machine"
  value       = azurerm_virtual_machine.vsocket_secondary.id
}

output "vsocket_secondary_vm_name" {
  description = "Name of the Secondary vSocket Virtual Machine"
  value       = azurerm_virtual_machine.vsocket_secondary.name
}

# Managed Disks Outputs
output "primary_disk_id" {
  description = "ID of the Primary vSocket Managed Disk"
  value       = azurerm_managed_disk.vSocket_disk_primary.id
}

output "primary_disk_name" {
  description = "Name of the Primary vSocket Managed Disk"
  value       = azurerm_managed_disk.vSocket_disk_primary.name
}

output "secondary_disk_id" {
  description = "ID of the Secondary vSocket Managed Disk"
  value       = azurerm_managed_disk.vSocket_disk_secondary.id
}

output "secondary_disk_name" {
  description = "Name of the Secondary vSocket Managed Disk"
  value       = azurerm_managed_disk.vSocket_disk_secondary.name
}

# User Assigned Identity
output "ha_identity_id" {
  description = "ID of the User Assigned Identity for HA"
  value       = azurerm_user_assigned_identity.CatoHaIdentity.id
}

output "ha_identity_principal_id" {
  description = "Principal ID of the HA Identity"
  value       = azurerm_user_assigned_identity.CatoHaIdentity.principal_id
}

# Role Assignments Outputs
output "primary_nic_role_assignment_id" {
  description = "Role Assignment ID for the Primary NIC"
  value       = azurerm_role_assignment.primary_nic_ha_role.id
}

output "secondary_nic_role_assignment_id" {
  description = "Role Assignment ID for the Secondary NIC"
  value       = azurerm_role_assignment.secondary_nic_ha_role.id
}

output "lan_subnet_role_assignment_id" {
  description = "Role Assignment ID for the LAN Subnet"
  value       = azurerm_role_assignment.lan-subnet-role.id
}

# LAN MAC Address Output
output "lan_secondary_mac_address" {
  description = "MAC Address of the Secondary LAN Interface"
  value       = data.azurerm_network_interface.lan_secondary.mac_address
}

# Reboot Status Outputs
output "vsocket_primary_reboot_status" {
  description = "Status of the Primary vSocket VM Reboot"
  value       = "Reboot triggered via Terraform"
  depends_on  = [null_resource.reboot_vsocket_primary]
}

output "vsocket_secondary_reboot_status" {
  description = "Status of the Secondary vSocket VM Reboot"
  value       = "Reboot triggered via Terraform"
  depends_on  = [null_resource.reboot_vsocket_secondary]
}