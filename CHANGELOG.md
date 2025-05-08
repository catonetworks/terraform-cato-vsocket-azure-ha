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