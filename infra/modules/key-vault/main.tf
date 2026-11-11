resource "azurerm_key_vault" "this" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.tenant_id
  sku_name                      = var.sku_name
  rbac_authorization_enabled    = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = var.soft_delete_retention_days
  public_network_access_enabled = var.public_network_access_enabled
  tags                          = var.tags

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = var.allowed_ip_ranges
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  scope                = azurerm_key_vault.this.id
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
  principal_type       = each.value.principal_type
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
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
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
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = var.diagnostics.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
