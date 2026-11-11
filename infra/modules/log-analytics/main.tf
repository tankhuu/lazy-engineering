resource "azurerm_log_analytics_workspace" "this" {
  name                           = var.name
  location                       = var.location
  resource_group_name            = var.resource_group_name
  sku                            = "PerGB2018"
  retention_in_days              = var.retention_in_days
  daily_quota_gb                 = var.daily_quota_gb
  internet_ingestion_access_type = var.internet_ingestion_enabled ? "Enabled" : "Disabled"
  internet_query_access_type     = var.internet_query_enabled ? "Enabled" : "Disabled"
  local_authentication_enabled   = false
  tags                           = var.tags
}
