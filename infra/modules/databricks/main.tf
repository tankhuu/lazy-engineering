resource "azurerm_databricks_workspace" "this" {
  name                                  = var.name
  location                              = var.location
  resource_group_name                   = var.resource_group_name
  sku                                   = "premium"
  managed_resource_group_name           = var.managed_resource_group_name
  public_network_access_enabled         = var.public_network_access_enabled
  network_security_group_rules_required = var.public_network_access_enabled ? "AllRules" : "NoAzureDatabricksRules"
  infrastructure_encryption_enabled     = true
  default_storage_firewall_enabled      = var.default_storage_firewall_enabled ? true : null
  access_connector_id                   = var.default_storage_firewall_enabled ? var.access_connector_id : null
  tags                                  = var.tags

  custom_parameters {
    no_public_ip                                         = true
    virtual_network_id                                   = var.virtual_network_id
    public_subnet_name                                   = var.host_subnet_name
    private_subnet_name                                  = var.container_subnet_name
    public_subnet_network_security_group_association_id  = var.host_subnet_nsg_association_id
    private_subnet_network_security_group_association_id = var.container_subnet_nsg_association_id
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_private_endpoint" "ui_api" {
  count = var.private_endpoint.enabled ? 1 : 0

  name                = "pe-${var.name}-ui-api"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.name}-ui-api"
    private_connection_resource_id = azurerm_databricks_workspace.this.id
    subresource_names              = ["databricks_ui_api"]
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

# One browser_authentication endpoint per region serves every workspace in that region.
resource "azurerm_private_endpoint" "browser_auth" {
  count = var.private_endpoint.enabled && var.private_endpoint.create_browser_authentication ? 1 : 0

  name                = "pe-${var.name}-browser-auth"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.name}-browser-auth"
    private_connection_resource_id = azurerm_databricks_workspace.this.id
    subresource_names              = ["browser_authentication"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = var.private_endpoint.private_dns_zone_id == null ? [] : [var.private_endpoint.private_dns_zone_id]

    content {
      name                 = "default"
      private_dns_zone_ids = [private_dns_zone_group.value]
    }
  }

  depends_on = [azurerm_private_endpoint.ui_api]
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  count = var.diagnostics.enabled ? 1 : 0

  name                       = "diag-to-law"
  target_resource_id         = azurerm_databricks_workspace.this.id
  log_analytics_workspace_id = var.diagnostics.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }
}
