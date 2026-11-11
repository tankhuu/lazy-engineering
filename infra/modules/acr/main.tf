resource "azurerm_container_registry" "this" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = "Premium"
  admin_enabled                 = false
  anonymous_pull_enabled        = false
  public_network_access_enabled = var.public_network_access_enabled
  network_rule_bypass_option    = "AzureServices"
  data_endpoint_enabled         = true
  export_policy_enabled         = var.public_network_access_enabled
  quarantine_policy_enabled     = var.quarantine_policy_enabled
  retention_policy_in_days      = var.untagged_retention_days
  zone_redundancy_enabled       = var.zone_redundancy_enabled
  tags                          = var.tags

  dynamic "georeplications" {
    for_each = var.georeplication_locations

    content {
      location                        = georeplications.value
      zone_redundancy_enabled         = var.zone_redundancy_enabled
      global_endpoint_routing_enabled = false
      tags                            = var.tags
    }
  }
}

resource "azurerm_private_endpoint" "this" {
  count = var.private_endpoint.enabled ? 1 : 0

  name                = "pe-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.name}"
    private_connection_resource_id = azurerm_container_registry.this.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = var.private_endpoint.private_dns_zone_id == null ? [] : [var.private_endpoint.private_dns_zone_id]

    content {
      name                 = "default"
      private_dns_zone_ids = [private_dns_zone_group.value]
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  count = var.diagnostics.enabled ? 1 : 0

  name                       = "diag-to-law"
  target_resource_id         = azurerm_container_registry.this.id
  log_analytics_workspace_id = var.diagnostics.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
