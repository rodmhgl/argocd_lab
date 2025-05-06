#region VPN Gateway
resource "azurerm_subnet" "gateway_subnet" {
  count = var.enable_vpn ? 1 : 0

  address_prefixes     = ["10.1.100.0/27"]
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = module.vnet.virtual_network_name
}

resource "azurerm_public_ip" "this" {
  count = var.enable_vpn ? 1 : 0

  name                = module.naming.public_ip.name_unique
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
}

resource "azurerm_virtual_network_gateway" "this" {
  count = var.enable_vpn ? 1 : 0

  name                = module.naming.virtual_network_gateway.name_unique
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  type                = "Vpn"
  sku                 = "VpnGw1"

  ip_configuration {
    name                          = "vpngwipconf"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway_subnet[0].id
    public_ip_address_id          = azurerm_public_ip.this[0].id
  }

  vpn_client_configuration {
    address_space        = ["172.20.0.0/24"]
    vpn_auth_types       = ["AAD"]
    aad_audience         = "c632b3df-fb67-4d84-bdcf-b95ad541b5c8"
    aad_issuer           = "https://sts.windows.net/${data.azurerm_client_config.current.tenant_id}/"
    aad_tenant           = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/"
    vpn_client_protocols = ["OpenVPN"]
  }
}

data "azuread_application_published_app_ids" "well_known" {
  count = var.enable_vpn ? 1 : 0
}

resource "azuread_service_principal" "azurevpn" {
  count = var.enable_vpn ? 1 : 0

  client_id    = data.azuread_application_published_app_ids.well_known[0].result.AzureVPN
  use_existing = true
}

resource "azuread_service_principal" "msgraph" {
  count = var.enable_vpn ? 1 : 0

  client_id    = data.azuread_application_published_app_ids.well_known[0].result.MicrosoftGraph
  use_existing = true
}

resource "azuread_service_principal_delegated_permission_grant" "example" {
  count = var.enable_vpn ? 1 : 0

  service_principal_object_id          = azuread_service_principal.azurevpn[0].object_id
  resource_service_principal_object_id = azuread_service_principal.msgraph[0].object_id
  claim_values                         = ["User.Read", "User.ReadBasic.All"]
}
#endregion