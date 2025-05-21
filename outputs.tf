output "clientID" {
  value = azurerm_user_assigned_identity.this.client_id
}

output "resource_group_name" {
  value       = azurerm_resource_group.this.name
  description = "The name of the resource group"
}
