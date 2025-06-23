# Changelog

## 0.0.1 (2025-03-19)

### Features
- Initial commit of HA module

## 0.0.3 (2025-05-3)

### Features
- Update to allow most recent version of Azure provider
- Updating module to fix siteAddSecondaryAzureVSocket null resource
- Added delay timer to allow HA configuration to complete

## 0.0.4 (2025-05-07)

### Features
- Added sleep null resources between primary socket creation and siteAddSecondaryAzureVSocket API to ensure enough time for socket to finish provisioning and upgrading.
- Added optional license resource and inputs used for commercial site deployments

## 0.0.5 (2025-05-15)

### Features
- Added sleep null resources between primary socket creation and 

## 0.1.0 (2025-06-03)
- Added Tags 
- Added native_network_range for Socket_Site to Standardize Naming of vars across modules 
- Moved Variable commands to variables.tf 
- Added ignore-changes to several resources 
- Added Delay for Destroy to prevent error when the socket hasn't been disconnected long enough to destroy the site. 
- changed lan_prefix to subnet_range_lan to standardize variable names 
- Added additional output 
- removed unused variable "vnet_prefix"
- Updated readme with additional information and tf-docs

## 0.1.1 (2025-06-13)

### Features 
- Added Naming convention to Managed Identity Resource 

## 0.2.0 (2025-06-23)

### Features 
- Updated module to use the new azurerm_linux_virtual_machine resource, as the azurerm_virtual_machine resource is no longer maintained by Azure/Terraform.

