#region public dns
provider "azurerm" {
  features {}
  subscription_id = var.dns_subscription_id
  alias           = "dns"
}

data "azurerm_dns_zone" "azurelaboratory" {
  provider = azurerm.dns

  name                = "azurelaboratory.com"
  resource_group_name = "rg-azurelaboratory-external-dns"
}

resource "azurerm_user_assigned_identity" "this" {
  name                = "certmanager-azurelaboratory"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_federated_identity_credential" "this" {
  name                = "cert-manager"
  resource_group_name = azurerm_resource_group.this.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.management_aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.this.id
  subject             = "system:serviceaccount:cert-manager:cert-manager"
}

resource "azurerm_role_assignment" "dns_zone_contributor" {
  provider = azurerm.dns

  principal_id         = azurerm_user_assigned_identity.this.principal_id
  scope                = data.azurerm_dns_zone.azurelaboratory.id
  role_definition_name = "DNS Zone Contributor"
}
#endregion

resource "azurerm_log_analytics_workspace" "this" {
  # name                = "${module.naming.log_analytics.name_unique}-workspace"
  name                = module.naming.log_analytics_workspace.name_unique
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  identity {
    type = "SystemAssigned"
  }

}

resource "azurerm_role_assignment" "aks_admin" {
  principal_id         = data.azurerm_client_config.current.object_id
  scope                = azurerm_resource_group.this.id
  role_definition_name = "Azure Kubernetes Service Cluster Admin Role"
}

#region management_aks
module "management_aks" {
  source  = "Azure/avm-res-containerservice-managedcluster/azurerm"
  version = "0.1.8"

  depends_on = [azurerm_role_assignment.private_dns_zone_contributor]

  name                       = module.naming.kubernetes_cluster.name_unique
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  sku_tier                   = "Free"
  private_cluster_enabled    = false
  private_dns_zone_id        = module.aks_private_dns_zone.resource_id
  dns_prefix_private_cluster = random_string.dns_prefix.result
  oidc_issuer_enabled        = true
  workload_identity_enabled  = true

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
    dns_service_ip      = "10.10.200.10"
    service_cidr        = "10.10.200.0/24"
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
  }

  default_node_pool = {
    name                         = "default"
    vm_size                      = "Standard_B2ms"
    auto_scaling_enabled         = true
    max_count                    = 3
    max_pods                     = 30
    min_count                    = 1
    vnet_subnet_id               = module.vnet.aks_subnet_id
    temporary_name_for_rotation  = "tmppool"
    only_critical_addons_enabled = false

    upgrade_settings = {
      max_surge = "10%"
    }
  }

  node_pools = {
    # unp1 = {
    #   name                 = "userpool1"
    #   vm_size              = "Standard_B2ms"
    #   auto_scaling_enabled = true
    #   max_count            = 3
    #   max_pods             = 30
    #   min_count            = 1
    #   os_disk_size_gb      = 128
    #   vnet_subnet_id       = azurerm_subnet.unp1_subnet.id

    #   upgrade_settings = {
    #     max_surge = "10%"
    #   }
    # }
    # unp2 = {
    #   name                 = "userpool2"
    #   vm_size              = "Standard_B2ms"
    #   auto_scaling_enabled = true
    #   max_count            = 3
    #   max_pods             = 30
    #   min_count            = 1
    #   os_disk_size_gb      = 128
    #   vnet_subnet_id       = azurerm_subnet.unp2_subnet.id

    #   upgrade_settings = {
    #     max_surge = "10%"
    #   }
    # }
  }

}

resource "azurerm_role_assignment" "mgmt_network_contributor" {
  principal_id         = module.management_aks.kubelet_identity_id
  scope                = module.vnet.id
  role_definition_name = "Network Contributor"
}
#endregion

# region dev_aks
module "dev_aks" {
  source  = "Azure/avm-res-containerservice-managedcluster/azurerm"
  version = "0.1.8"

  count = var.enabled_dev_aks ? 1 : 0

  depends_on = [azurerm_role_assignment.private_dns_zone_contributor]

  name                       = "${module.naming.kubernetes_cluster.name_unique}-dev"
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  sku_tier                   = "Free"
  private_cluster_enabled    = false
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
    dns_service_ip      = "10.10.200.10"
    service_cidr        = "10.10.200.0/24"
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
  }

  default_node_pool = {
    name                         = "default"
    vm_size                      = "Standard_B2ms"
    auto_scaling_enabled         = true
    max_count                    = 3
    max_pods                     = 30
    min_count                    = 1
    vnet_subnet_id               = module.vnet.aks_subnet_id
    temporary_name_for_rotation  = "tmppool"
    only_critical_addons_enabled = false

    upgrade_settings = {
      max_surge = "10%"
    }
  }

  node_pools = {}

}

resource "azurerm_role_assignment" "dev_network_contributor" {
  count = var.enabled_dev_aks ? 1 : 0

  principal_id         = module.dev_aks[0].kubelet_identity_id
  scope                = module.vnet.id
  role_definition_name = "Network Contributor"
}
#endregion

#region prod_aks
module "prod_aks" {
  source  = "Azure/avm-res-containerservice-managedcluster/azurerm"
  version = "0.1.8"

  count = var.enabled_prod_aks ? 1 : 0

  depends_on = [azurerm_role_assignment.private_dns_zone_contributor]

  name                       = "${module.naming.kubernetes_cluster.name_unique}-prod"
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  sku_tier                   = "Free"
  private_cluster_enabled    = false
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
    dns_service_ip      = "10.10.200.10"
    service_cidr        = "10.10.200.0/24"
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
  }

  default_node_pool = {
    name                         = "default"
    vm_size                      = "Standard_B2ms"
    auto_scaling_enabled         = true
    max_count                    = 3
    max_pods                     = 30
    min_count                    = 1
    vnet_subnet_id               = module.vnet.aks_subnet_id
    temporary_name_for_rotation  = "tmppool"
    only_critical_addons_enabled = false

    upgrade_settings = {
      max_surge = "10%"
    }
  }

  node_pools = {
  }

}

resource "azurerm_role_assignment" "prod_network_contributor" {
  count = var.enabled_prod_aks ? 1 : 0

  principal_id         = module.prod_aks[0].kubelet_identity_id
  scope                = module.vnet.id
  role_definition_name = "Network Contributor"
}
#endregion