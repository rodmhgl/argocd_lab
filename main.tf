data "azurerm_client_config" "current" {}

#region Resource Group and Naming
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.3"
}

resource "azurerm_resource_group" "this" {
  location = "eastus"
  name     = module.naming.resource_group.name_unique
  tags = {
    "hidden-title" = "Argo CD Demo Lab"
  }
}
#endregion

#region Private DNS Zone
module "aks_private_dns_zone" {
  source  = "Azure/avm-res-network-privatednszone/azurerm"
  version = "0.3.3"

  domain_name         = "privatelink.${azurerm_resource_group.this.location}.azmk8s.io"
  resource_group_name = azurerm_resource_group.this.name
  enable_telemetry    = false
  virtual_network_links = {
    vnet_link = {
      vnetlinkname     = "privatelink-${azurerm_resource_group.this.location}-azmk8s-io"
      vnetid           = module.vnet.id
      autoregistration = false
      tags             = {}
    }
  }
}

resource "azurerm_user_assigned_identity" "identity" {
  location            = azurerm_resource_group.this.location
  name                = "aks-identity"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_role_assignment" "private_dns_zone_contributor" {
  principal_id         = azurerm_user_assigned_identity.identity.principal_id
  scope                = module.aks_private_dns_zone.resource_id
  role_definition_name = "Private DNS Zone Contributor"
}

resource "azurerm_role_assignment" "network_contributor" {
  principal_id         = azurerm_user_assigned_identity.identity.principal_id
  scope                = module.aks_private_dns_zone.resource_id
  role_definition_name = "Network Contributor"
}

resource "random_string" "dns_prefix" {
  length  = 10    # Set the length of the string
  lower   = true  # Use lowercase letters
  numeric = true  # Include numbers
  special = false # No special characters
  upper   = false # No uppercase letters
}
#endregion
