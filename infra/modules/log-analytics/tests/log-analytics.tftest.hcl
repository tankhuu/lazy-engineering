mock_provider "azurerm" {}

variables {
  name                = "log-plat-dev-weu-01"
  location            = "westeurope"
  resource_group_name = "rg-plat-dev-weu-01"
  tags                = { environment = "dev" }
}

run "local_auth_disabled_and_tagged" {
  command = plan

  assert {
    condition     = azurerm_log_analytics_workspace.this.local_authentication_enabled == false
    error_message = "Local (shared key) authentication must be disabled."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.tags["environment"] == "dev"
    error_message = "Tags must be applied."
  }
}

run "private_ingestion_toggle" {
  command = plan

  variables {
    internet_ingestion_enabled = false
    internet_query_enabled     = false
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.internet_ingestion_access_type == "Disabled" && azurerm_log_analytics_workspace.this.internet_query_access_type == "Disabled"
    error_message = "Public ingestion and query must be disabled when requested."
  }
}

run "rejects_short_retention" {
  command = plan

  variables {
    retention_in_days = 7
  }

  expect_failures = [var.retention_in_days]
}
