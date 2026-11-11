output "access_connector_id" {
  description = "Access connector resource ID."
  value       = azurerm_databricks_access_connector.this.id
}

output "catalog_names" {
  description = "Created catalog names."
  value       = [for c in databricks_catalog.this : c.name]
}

output "cluster_policy_id" {
  description = "ID of the jobs cluster policy."
  value       = databricks_cluster_policy.jobs.id
}

output "external_location_url" {
  description = "abfss:// URL of the UC managed storage root."
  value       = local.storage_url
}

output "metastore_id" {
  description = "Metastore assigned to the workspace."
  value       = local.metastore_id
}

output "storage_account_id" {
  description = "UC storage account resource ID."
  value       = azurerm_storage_account.uc.id
}
