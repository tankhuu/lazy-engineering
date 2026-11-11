resource "azurerm_resource_group" "this" {
  for_each = var.resource_groups

  name     = each.value
  location = var.location
  tags     = var.tags
}
