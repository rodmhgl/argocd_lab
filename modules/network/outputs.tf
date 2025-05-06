output "aks_subnet_id" {
  description = "The ID of the AKS subnet."
  value       = azurerm_subnet.subnet.id
}

output "id" {
  description = "The ID of the virtual network."
  value       = azurerm_virtual_network.this.id
}

output "virtual_network_name" {
  description = "The name of the virtual network."
  value       = azurerm_virtual_network.this.name
}
