output "ids" {
  description = "Resource group IDs keyed by purpose."
  value       = { for k, rg in azurerm_resource_group.this : k => rg.id }
}

output "names" {
  description = "Resource group names keyed by purpose."
  value       = { for k, rg in azurerm_resource_group.this : k => rg.name }
}
