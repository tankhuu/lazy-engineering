output "id" {
  description = "Container registry resource ID (scope for AcrPull)."
  value       = azurerm_container_registry.this.id
}

output "login_server" {
  description = "Registry login server, e.g. crplatdevweu01.azurecr.io."
  value       = azurerm_container_registry.this.login_server
}

output "name" {
  description = "Container registry name."
  value       = azurerm_container_registry.this.name
}
