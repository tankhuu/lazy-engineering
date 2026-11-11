output "id" {
  description = "Virtual network resource ID."
  value       = azurerm_virtual_network.this.id
}

output "name" {
  description = "Virtual network name."
  value       = azurerm_virtual_network.this.name
}

output "nat_gateway_id" {
  description = "NAT Gateway ID, or null when disabled."
  value       = try(azurerm_nat_gateway.this[0].id, null)
}

output "nsg_association_ids" {
  description = "Subnet-NSG association IDs keyed by subnet name (required by Databricks VNet injection)."
  value       = { for k, v in azurerm_subnet_network_security_group_association.this : k => v.id }
}

output "nsg_ids" {
  description = "NSG IDs keyed by subnet name."
  value       = { for k, v in azurerm_network_security_group.this : k => v.id }
}

output "private_dns_zone_ids" {
  description = "Locally created private DNS zone IDs keyed by zone name."
  value       = { for k, v in azurerm_private_dns_zone.this : k => v.id }
}

output "route_table_id" {
  description = "Route table ID, or null when no egress firewall is configured."
  value       = try(azurerm_route_table.this[0].id, null)
}

output "subnet_ids" {
  description = "Subnet IDs keyed by subnet name."
  value       = { for k, v in azurerm_subnet.this : k => v.id }
}
