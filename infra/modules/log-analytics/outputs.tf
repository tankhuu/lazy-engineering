output "id" {
  description = "Log Analytics workspace resource ID (use for diagnostic settings and AKS oms_agent)."
  value       = azurerm_log_analytics_workspace.this.id
}

output "name" {
  description = "Log Analytics workspace name."
  value       = azurerm_log_analytics_workspace.this.name
}

output "workspace_id" {
  description = "Log Analytics workspace (customer) ID used by agents and queries."
  value       = azurerm_log_analytics_workspace.this.workspace_id
}
