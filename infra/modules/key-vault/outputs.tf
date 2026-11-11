output "id" {
  description = "Key Vault resource ID."
  value       = azurerm_key_vault.this.id
}

output "name" {
  description = "Key Vault name."
  value       = azurerm_key_vault.this.name
}

output "private_endpoint_id" {
  description = "Private endpoint ID, or null when disabled."
  value       = try(azurerm_private_endpoint.this[0].id, null)
}

output "vault_uri" {
  description = "Key Vault URI."
  value       = azurerm_key_vault.this.vault_uri
}
