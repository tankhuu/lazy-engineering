mock_provider "azurerm" {
  mock_resource "azurerm_kubernetes_cluster" {
    defaults = {
      id              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-aks-plat-dev-weu-01/providers/Microsoft.ContainerService/managedClusters/aks-plat-dev-weu-01"
      oidc_issuer_url = "https://westeurope.oic.prod-aks.azure.com/00000000-0000-0000-0000-000000000000/11111111-1111-1111-1111-111111111111/"
    }
  }
}

variables {
  name                       = "aks-plat-dev-weu-01"
  location                   = "westeurope"
  resource_group_name        = "rg-plat-dev-weu-01"
  kubernetes_version         = "1.33"
  tenant_id                  = "00000000-0000-0000-0000-000000000000"
  admin_group_object_ids     = ["11111111-1111-1111-1111-111111111111"]
  nodes_subnet_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/snet-aks-nodes"
  log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.OperationalInsights/workspaces/log"

  user_pools = {
    apps = { vm_size = "Standard_D8ds_v5", min_count = 2, max_count = 10 }
  }

  workload_identities = {
    externaldns = { namespace = "external-dns", service_account = "external-dns" }
  }
}

run "secure_cluster_defaults" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.private_cluster_enabled && azurerm_kubernetes_cluster.this.local_account_disabled
    error_message = "Cluster must be private with local accounts disabled."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.oidc_issuer_enabled && azurerm_kubernetes_cluster.this.workload_identity_enabled
    error_message = "OIDC issuer and workload identity must be enabled."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.azure_active_directory_role_based_access_control[0].azure_rbac_enabled
    error_message = "Entra RBAC must be enabled."
  }
}

run "overlay_cilium_networking" {
  command = plan

  assert {
    condition = (
      azurerm_kubernetes_cluster.this.network_profile[0].network_plugin_mode == "overlay" &&
      azurerm_kubernetes_cluster.this.network_profile[0].network_data_plane == "cilium" &&
      azurerm_kubernetes_cluster.this.network_profile[0].dns_service_ip == "172.16.0.10"
    )
    error_message = "Expected Azure CNI Overlay with Cilium and dns_service_ip inside service_cidr."
  }
}

run "system_pool_is_isolated_and_rotatable" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].only_critical_addons_enabled && azurerm_kubernetes_cluster.this.default_node_pool[0].temporary_name_for_rotation != null
    error_message = "System pool must be tainted for critical add-ons and rotate instead of replacing the cluster."
  }

  assert {
    condition     = azurerm_kubernetes_cluster_node_pool.user["apps"].mode == "User" && azurerm_kubernetes_cluster_node_pool.user["apps"].auto_scaling_enabled
    error_message = "User pools must be autoscaled User mode pools."
  }
}

run "workload_identity_subject" {
  command = plan

  assert {
    condition     = azurerm_federated_identity_credential.workload["externaldns"].subject == "system:serviceaccount:external-dns:external-dns"
    error_message = "Federated credential subject must match the service account exactly."
  }
}

run "no_acr_or_route_table_roles_by_default" {
  command = plan

  assert {
    condition     = length(azurerm_role_assignment.kubelet_acr_pull) == 0 && length(azurerm_role_assignment.control_plane_route_table) == 0
    error_message = "Optional role assignments must be off unless requested."
  }
}

run "rejects_patch_version" {
  command = plan

  variables {
    kubernetes_version = "1.33.2"
  }

  expect_failures = [var.kubernetes_version]
}

run "rejects_long_pool_name" {
  command = plan

  variables {
    user_pools = { applicationpool1 = { vm_size = "Standard_D4ds_v5", min_count = 1, max_count = 2 } }
  }

  expect_failures = [var.user_pools]
}
