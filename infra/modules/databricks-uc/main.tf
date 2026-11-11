locals {
  metastore_id    = var.metastore.create ? databricks_metastore.this[0].id : var.metastore.id
  storage_url     = "abfss://${azurerm_storage_container.uc.name}@${azurerm_storage_account.uc.name}.dfs.core.windows.net/"
  pe_subresources = var.private_endpoint.enabled ? toset(["blob", "dfs"]) : toset([])
}

## --- Azure: storage + access connector ------------------------------------

resource "azurerm_databricks_access_connector" "this" {
  name                = var.access_connector_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_storage_account" "uc" {
  name                              = var.storage_account_name
  location                          = var.location
  resource_group_name               = var.resource_group_name
  account_kind                      = "StorageV2"
  account_tier                      = "Standard"
  account_replication_type          = var.storage_replication_type
  is_hns_enabled                    = true
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  shared_access_key_enabled         = false
  local_user_enabled                = false
  default_to_oauth_authentication   = true
  allow_nested_items_to_be_public   = false
  cross_tenant_replication_enabled  = false
  infrastructure_encryption_enabled = true
  public_network_access             = var.private_endpoint.enabled ? "Disabled" : "Enabled"
  tags                              = var.tags

  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]

    private_link_access {
      endpoint_resource_id = azurerm_databricks_access_connector.this.id
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "uc" {
  name                  = "unity-catalog"
  storage_account_id    = azurerm_storage_account.uc.id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_role_assignment" "connector_blob" {
  scope                = azurerm_storage_account.uc.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_private_endpoint" "storage" {
  for_each = local.pe_subresources

  name                = "pe-${var.storage_account_name}-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.storage_account_name}-${each.key}"
    private_connection_resource_id = azurerm_storage_account.uc.id
    subresource_names              = [each.key]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = lookup(var.private_endpoint.private_dns_zone_ids, each.key, null) == null ? [] : [var.private_endpoint.private_dns_zone_ids[each.key]]

    content {
      name                 = "default"
      private_dns_zone_ids = [private_dns_zone_group.value]
    }
  }
}

## --- Databricks account: metastore ----------------------------------------

resource "databricks_metastore" "this" {
  count    = var.metastore.create ? 1 : 0
  provider = databricks.account

  name          = var.metastore.name
  region        = var.location
  owner         = var.metastore.owner
  force_destroy = false
}

resource "databricks_metastore_assignment" "this" {
  provider = databricks.account

  metastore_id = local.metastore_id
  workspace_id = var.workspace_id
}

## --- Databricks workspace: credentials, locations, catalogs ---------------

resource "databricks_storage_credential" "this" {
  provider = databricks.workspace

  name    = "sc-${var.environment}-uc"
  comment = "Managed identity of ${var.access_connector_name}"

  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.this.id
  }

  # Credentials can only be created once the workspace is attached to a metastore.
  depends_on = [databricks_metastore_assignment.this]
}

resource "databricks_external_location" "this" {
  provider = databricks.workspace

  name            = "el-${var.environment}-uc"
  url             = local.storage_url
  credential_name = databricks_storage_credential.this.name
  comment         = "Unity Catalog managed storage for ${var.environment}"

  # Validation reads the container, so RBAC must exist first.
  depends_on = [azurerm_role_assignment.connector_blob]
}

resource "databricks_catalog" "this" {
  for_each = var.catalogs
  provider = databricks.workspace

  name         = each.key
  comment      = each.value.comment
  storage_root = "${local.storage_url}catalogs/${each.key}"

  depends_on = [databricks_external_location.this]
}

resource "databricks_grants" "catalog" {
  for_each = { for k, v in var.catalogs : k => v if length(v.grants) > 0 }
  provider = databricks.workspace

  catalog = databricks_catalog.this[each.key].name

  dynamic "grant" {
    for_each = each.value.grants

    content {
      principal  = grant.key
      privileges = grant.value
    }
  }
}

resource "databricks_cluster_policy" "jobs" {
  provider = databricks.workspace

  name = "jobs-${var.environment}"
  definition = jsonencode({
    "autotermination_minutes" = { type = "range", maxValue = var.cluster_policy.max_autotermination_minutes, defaultValue = 30 }
    "data_security_mode"      = { type = "allowlist", values = ["SINGLE_USER", "USER_ISOLATION"] }
    "node_type_id"            = { type = "allowlist", values = var.cluster_policy.allowed_node_types }
    "spark_version"           = { type = "regex", pattern = var.cluster_policy.spark_version_regex }
    "custom_tags.cost_center" = { type = "fixed", value = lookup(var.tags, "cost_center", "unassigned") }
    "custom_tags.environment" = { type = "fixed", value = var.environment }
  })
}
