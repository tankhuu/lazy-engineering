resource "azurerm_kubernetes_cluster" "this" {
  name                      = var.name
  location                  = var.location
  resource_group_name       = var.resource_group_name
  dns_prefix                = var.name
  kubernetes_version        = var.kubernetes_version
  sku_tier                  = var.sku_tier
  node_resource_group       = "rg-${var.name}-nodes"
  automatic_upgrade_channel = var.automatic_upgrade_channel
  node_os_upgrade_channel   = "NodeImage"

  private_cluster_enabled      = var.private_cluster_enabled
  private_dns_zone_id          = var.private_cluster_enabled ? var.private_dns_zone_id : null
  local_account_disabled       = true
  oidc_issuer_enabled          = true
  workload_identity_enabled    = true
  image_cleaner_enabled        = true
  image_cleaner_interval_hours = 48
  azure_policy_enabled         = var.enable_azure_policy
  run_command_enabled          = false
  tags                         = var.tags

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_pool.vm_size
    vnet_subnet_id               = var.nodes_subnet_id
    zones                        = var.system_pool.zones
    auto_scaling_enabled         = true
    min_count                    = var.system_pool.min_count
    max_count                    = var.system_pool.max_count
    max_pods                     = var.system_pool.max_pods
    os_sku                       = var.system_pool.os_sku
    os_disk_type                 = "Ephemeral"
    only_critical_addons_enabled = true
    orchestrator_version         = var.kubernetes_version
    temporary_name_for_rotation  = "systemtmp"
    host_encryption_enabled      = var.host_encryption_enabled
    tags                         = var.tags

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }

  node_provisioning_profile {
    mode = var.node_auto_provisioning ? "Auto" : "Manual"
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
    load_balancer_sku   = "standard"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  oms_agent {
    log_analytics_workspace_id      = var.log_analytics_workspace_id
    msi_auth_for_monitoring_enabled = true
  }

  monitor_metrics {}

  dynamic "microsoft_defender" {
    for_each = var.enable_defender ? [1] : []

    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  workload_autoscaler_profile {
    keda_enabled                    = var.enable_keda
    vertical_pod_autoscaler_enabled = var.enable_vpa
  }

  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    duration    = var.maintenance_window.duration_hours
    day_of_week = var.maintenance_window.day_of_week
    start_time  = var.maintenance_window.start_time
    utc_offset  = var.maintenance_window.utc_offset
  }

  maintenance_window_node_os {
    frequency   = "Weekly"
    interval    = 1
    duration    = var.maintenance_window.duration_hours
    day_of_week = var.maintenance_window.day_of_week
    start_time  = var.maintenance_window.start_time
    utc_offset  = var.maintenance_window.utc_offset
  }

  lifecycle {
    prevent_destroy = true
    # The cluster autoscaler owns node_count.
    ignore_changes = [default_node_pool[0].node_count]
  }

  # AKS validates subnet/route-table/DNS permissions of the control-plane identity at create time.
  depends_on = [
    azurerm_role_assignment.control_plane_subnet,
    azurerm_role_assignment.control_plane_route_table,
    azurerm_role_assignment.control_plane_private_dns,
  ]
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  for_each = var.user_pools

  name                    = each.key
  kubernetes_cluster_id   = azurerm_kubernetes_cluster.this.id
  vm_size                 = each.value.vm_size
  vnet_subnet_id          = var.nodes_subnet_id
  zones                   = each.value.zones
  auto_scaling_enabled    = true
  min_count               = each.value.min_count
  max_count               = each.value.max_count
  max_pods                = each.value.max_pods
  os_sku                  = each.value.os_sku
  os_disk_type            = each.value.os_disk_type
  orchestrator_version    = var.kubernetes_version
  mode                    = "User"
  node_labels             = each.value.labels
  node_taints             = each.value.taints
  host_encryption_enabled = var.host_encryption_enabled
  tags                    = var.tags

  upgrade_settings {
    max_surge = each.value.max_surge
  }

  lifecycle {
    ignore_changes = [node_count]
  }
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  count = var.enable_diagnostics ? 1 : 0

  name                       = "diag-to-law"
  target_resource_id         = azurerm_kubernetes_cluster.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = toset(var.diagnostic_log_categories)

    content {
      category = enabled_log.value
    }
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
