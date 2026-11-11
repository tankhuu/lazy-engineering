resource "azurerm_resource_group" "state" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "state" {
  name                            = var.storage_account_name
  resource_group_name             = azurerm_resource_group.state.name
  location                        = azurerm_resource_group.state.location
  account_tier                    = "Standard"
  account_replication_type        = var.replication_type
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  shared_access_key_enabled       = false
  local_user_enabled              = false
  allow_nested_items_to_be_public = false
  default_to_oauth_authentication = true
  public_network_access           = length(var.allowed_ip_ranges) > 0 || var.allow_public_access ? "Enabled" : "Disabled"
  tags                            = var.tags

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = var.soft_delete_retention_days
    }

    container_delete_retention_policy {
      days = var.soft_delete_retention_days
    }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = var.allowed_ip_ranges
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "state" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_management_lock" "state" {
  name       = "lock-${var.storage_account_name}"
  scope      = azurerm_storage_account.state.id
  lock_level = "CanNotDelete"
  notes      = "Terraform remote state. Remove only through a reviewed change."
}

resource "azurerm_role_assignment" "state_writers" {
  for_each = var.state_writer_principals

  scope                            = azurerm_storage_account.state.id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = each.value.principal_id
  principal_type                   = each.value.principal_type
  skip_service_principal_aad_check = each.value.principal_type == "ServicePrincipal"
}

resource "azurerm_role_assignment" "state_readers" {
  for_each = var.state_reader_principals

  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = each.value.principal_id
  principal_type       = each.value.principal_type
}
