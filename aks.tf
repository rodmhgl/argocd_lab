#region AKS
module "private" {
  source  = "Azure/avm-res-containerservice-managedcluster/azurerm"
  version = "0.1.8"

  depends_on = [azurerm_role_assignment.private_dns_zone_contributor]

  name                       = module.naming.kubernetes_cluster.name_unique
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  sku_tier                   = "Standard"
  private_cluster_enabled    = true
  private_dns_zone_id        = module.aks_private_dns_zone.resource_id
  dns_prefix_private_cluster = random_string.dns_prefix.result

  azure_active_directory_role_based_access_control = {
    azure_rbac_enabled     = true
    admin_group_object_ids = [var.default_admin_group_object_id]
    tenant_id              = data.azurerm_client_config.current.tenant_id
  }

  managed_identities = {
    system_assigned            = false
    user_assigned_resource_ids = [azurerm_user_assigned_identity.identity.id]
  }
  network_profile = {
    dns_service_ip = "10.10.200.10"
    service_cidr   = "10.10.200.0/24"
    network_plugin = "azure"
  }

  default_node_pool = {
    name                         = "default"
    vm_size                      = "Standard_B2ms"
    auto_scaling_enabled         = true
    max_count                    = 3
    max_pods                     = 30
    min_count                    = 1
    vnet_subnet_id               = azurerm_subnet.subnet.id
    only_critical_addons_enabled = true

    upgrade_settings = {
      max_surge = "10%"
    }
  }

  node_pools = {
    unp1 = {
      name                 = "userpool1"
      vm_size              = "Standard_B2ms"
      auto_scaling_enabled = true
      max_count            = 3
      max_pods             = 30
      min_count            = 1
      os_disk_size_gb      = 128
      vnet_subnet_id       = azurerm_subnet.unp1_subnet.id

      upgrade_settings = {
        max_surge = "10%"
      }
    }
    unp2 = {
      name                 = "userpool2"
      vm_size              = "Standard_B2ms"
      auto_scaling_enabled = true
      max_count            = 3
      max_pods             = 30
      min_count            = 1
      os_disk_size_gb      = 128
      vnet_subnet_id       = azurerm_subnet.unp2_subnet.id

      upgrade_settings = {
        max_surge = "10%"
      }
    }
  }

}

resource "azurerm_role_assignment" "aks_admin" {
  principal_id         = data.azurerm_client_config.current.object_id
  scope                = module.private.resource_id
  role_definition_name = "Azure Kubernetes Service Cluster Admin Role"
}
#endregion
