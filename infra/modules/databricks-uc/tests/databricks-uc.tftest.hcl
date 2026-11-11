mock_provider "azurerm" {}

mock_provider "databricks" {
  alias = "account"
}

mock_provider "databricks" {
  alias = "workspace"
}

variables {
  environment           = "dev"
  location              = "westeurope"
  resource_group_name   = "rg-plat-dev-weu-01"
  storage_account_name  = "stplatdevweuuc"
  access_connector_name = "dbac-plat-dev-weu-01"
  workspace_id          = "1234567890123456"
  metastore             = { create = false, id = "11111111-2222-3333-4444-555555555555" }
  tags                  = { cost_center = "CC-1234" }

  catalogs = {
    dev_bronze = {
      comment = "Raw ingestion"
      grants  = { data_engineers = ["USE_CATALOG", "CREATE_SCHEMA"] }
    }
  }
}

run "storage_is_keyless_hns" {
  command = plan

  assert {
    condition     = azurerm_storage_account.uc.is_hns_enabled && azurerm_storage_account.uc.shared_access_key_enabled == false
    error_message = "UC storage must be ADLS Gen2 with shared keys disabled."
  }

  assert {
    condition     = azurerm_storage_account.uc.network_rules[0].default_action == "Deny"
    error_message = "UC storage firewall must default to Deny."
  }
}

run "uses_existing_metastore" {
  command = plan

  assert {
    condition     = length(databricks_metastore.this) == 0 && databricks_metastore_assignment.this.metastore_id == "11111111-2222-3333-4444-555555555555"
    error_message = "Existing metastore must be assigned without creating a new one."
  }
}

run "catalog_storage_under_external_location" {
  command = plan

  assert {
    condition     = startswith(databricks_catalog.this["dev_bronze"].storage_root, "abfss://unity-catalog@stplatdevweuuc.dfs.core.windows.net/catalogs/")
    error_message = "Catalog storage_root must live under the UC external location."
  }
}

run "cluster_policy_fixes_cost_tags" {
  command = plan

  assert {
    condition     = jsondecode(databricks_cluster_policy.jobs.definition)["custom_tags.cost_center"].value == "CC-1234"
    error_message = "Cluster policy must pin the cost_center tag."
  }
}

run "requires_metastore_id_when_not_creating" {
  command = plan

  variables {
    metastore = { create = false }
  }

  expect_failures = [var.metastore]
}
