#region VNET
module "vnet" {
  source = "./modules/network"

  virtual_network_name = "private-vnet"
  resource_group_name  = azurerm_resource_group.this.name
  location             = azurerm_resource_group.this.location
}
#endregion
