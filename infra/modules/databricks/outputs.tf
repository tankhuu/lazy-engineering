output "id" {
  description = "Workspace ARM resource ID (azure_workspace_resource_id for the databricks provider)."
  value       = azurerm_databricks_workspace.this.id
}

output "managed_resource_group_id" {
  description = "Databricks-managed resource group ID."
  value       = azurerm_databricks_workspace.this.managed_resource_group_id
}

output "name" {
  description = "Workspace name."
  value       = azurerm_databricks_workspace.this.name
}

output "workspace_id" {
  description = "Numeric Databricks workspace ID (for metastore assignment)."
  value       = azurerm_databricks_workspace.this.workspace_id
}

output "workspace_url" {
  description = "Workspace URL without scheme, e.g. adb-123.4.azuredatabricks.net."
  value       = azurerm_databricks_workspace.this.workspace_url
}
