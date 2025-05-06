resource "azurerm_virtual_network" "this" {
  name                = var.virtual_network_name
  address_space       = ["10.1.0.0/16"]
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_subnet" "subnet" {
  address_prefixes     = ["10.1.0.0/24"]
  name                 = "default"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
}

resource "azurerm_subnet" "unp1_subnet" {
  address_prefixes     = ["10.1.1.0/24"]
  name                 = "unp1"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
}

resource "azurerm_subnet" "unp2_subnet" {
  address_prefixes     = ["10.1.2.0/24"]
  name                 = "unp2"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
}
