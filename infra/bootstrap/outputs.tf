output "backend_config" {
  description = "Values for TFSTATE_RESOURCE_GROUP / TFSTATE_STORAGE_ACCOUNT used by infra/deployment/backend.hcl."
  value = {
    resource_group_name  = azurerm_resource_group.state.name
    storage_account_name = azurerm_storage_account.state.name
    container_name       = azurerm_storage_container.state.name
    use_azuread_auth     = true
  }
}

output "storage_account_id" {
  description = "Resource ID of the state storage account."
  value       = azurerm_storage_account.state.id
}
