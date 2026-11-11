---
name: aks-terraform
description: Production AKS with Terraform (azurerm 5.x) - private cluster, Azure CNI Overlay with Cilium, Entra RBAC, workload identity, system/user node pools, autoscaling, upgrades, Key Vault CSI, monitoring, ACR integration. Use when creating or modifying infra/modules/aks or planning AKS upgrades.
metadata:
  origin: lazy-engineering
---

# AKS with Terraform

Reference implementation: `infra/modules/aks`. Workload manifests: ECC `kubernetes-patterns` skill.

## Cluster skeleton

```hcl
resource "azurerm_kubernetes_cluster" "this" {
  name                      = var.name
  location                  = var.location
  resource_group_name       = var.resource_group_name
  dns_prefix                = var.name
  kubernetes_version        = var.kubernetes_version          # e.g. "1.31"
  sku_tier                  = var.sku_tier                    # Standard in prod
  node_resource_group       = "rg-${var.name}-nodes"
  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"

  private_cluster_enabled             = true
  private_dns_zone_id                 = var.private_dns_zone_id   # or "System"
  local_account_disabled              = true
  oidc_issuer_enabled                 = true
  workload_identity_enabled           = true
  image_cleaner_enabled               = true
  image_cleaner_interval_hours        = 48
  azure_policy_enabled                = var.enable_azure_policy

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_pool.vm_size
    vnet_subnet_id               = var.nodes_subnet_id
    zones                        = ["1", "2", "3"]
    auto_scaling_enabled         = true
    min_count                    = var.system_pool.min_count
    max_count                    = var.system_pool.max_count
    only_critical_addons_enabled = true
    orchestrator_version         = var.kubernetes_version
    temporary_name_for_rotation  = "systemtmp"
    upgrade_settings { max_surge = "33%" }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }

  node_provisioning_profile {           # required block in azurerm 5.x
    mode = "Manual"                     # "Auto" = Node Auto Provisioning (Karpenter)
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = var.admin_group_object_ids
    tenant_id              = var.tenant_id
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = cidrhost(var.service_cidr, 10)
    outbound_type       = var.outbound_type
  }

  key_vault_secrets_provider { secret_rotation_enabled = true }
  oms_agent {
    log_analytics_workspace_id      = var.log_analytics_workspace_id
    msi_auth_for_monitoring_enabled = true
  }
  monitor_metrics {}

  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "02:00"
    utc_offset  = "+00:00"
  }

  lifecycle {
    # autoscaler owns node_count. kubernetes_version stays a minor alias ("1.34"), so
    # patch auto-upgrades do not drift it; don't ignore it or minor upgrades become invisible.
    ignore_changes = [default_node_pool[0].node_count]
  }
}
```

## Identities

- Control plane: user-assigned identity, `Network Contributor` on the nodes subnet (and route table when `userDefinedRouting`), `Private DNS Zone Contributor` on the private DNS zone when BYO.
- Gate optional role assignments on plain bools (`route_table.manage_role`, `private_dns_zone_manage_role`, `acr.attach`), never on IDs: IDs computed in the same plan make `count` unknown and the plan fails.
- Kubelet: `AcrPull` on ACR (`one(azurerm_kubernetes_cluster.this.kubelet_identity[*].object_id)`).
- Workloads: per-app `azurerm_user_assigned_identity` + `azurerm_federated_identity_credential` with `issuer = azurerm_kubernetes_cluster.this.oidc_issuer_url` and `subject = "system:serviceaccount:<ns>:<sa>"`.

## User node pools

```hcl
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  for_each              = var.user_pools
  name                  = each.key                         # <= 12 chars
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = each.value.vm_size
  vnet_subnet_id        = var.nodes_subnet_id
  zones                 = each.value.zones
  auto_scaling_enabled  = true
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  orchestrator_version  = var.kubernetes_version
  node_labels           = each.value.labels
  node_taints           = each.value.taints
  mode                  = "User"
  upgrade_settings { max_surge = "33%" }
  lifecycle { ignore_changes = [node_count] }
}
```

Changing `vm_size` replaces the pool: add a new pool key, migrate workloads (cordon/drain via runbook, not Claude), remove the old key.

## Upgrade runbook (minor version)

1. `az aks get-upgrades` -> pick next minor only.
2. PR 1: bump `kubernetes_version` (control plane) - plan shows in-place update.
3. PR 2..n: bump `orchestrator_version` per pool (or move all if low risk).
4. Check deprecated APIs and PDBs before merging; keep `max_surge` sane for capacity/quota.

## Common pitfalls

- `dns_service_ip` must be inside `service_cidr`; neither may overlap VNet, hub, or on-prem.
- `private_cluster_enabled` change = replacement.
- With `outbound_type = "userDefinedRouting"`, the route table must be associated with the subnet before cluster creation (add `depends_on` on the association with a comment).
- Quota: check vCPU family quota in the region for `max_count * max_surge`.
