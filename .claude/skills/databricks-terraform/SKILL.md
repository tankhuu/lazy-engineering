---
name: databricks-terraform
description: Azure Databricks with Terraform - premium workspace with VNet injection and Secure Cluster Connectivity, Private Link (front-end, back-end, browser auth), Unity Catalog (metastore, access connector, storage credential, external locations, catalogs, grants), account vs workspace provider split, cluster policies. Use when creating or modifying infra/modules/databricks or infra/modules/databricks-uc.
metadata:
  origin: lazy-engineering
---

# Azure Databricks with Terraform

Reference implementation: `infra/modules/databricks` (azurerm) and `infra/modules/databricks-uc` (databricks provider).

## Two providers, three scopes

| Scope | Provider | Config |
|-------|----------|--------|
| Azure resources (workspace, subnets, PE, access connector, ADLS) | `azurerm` | normal |
| Account (metastore, assignment, account groups) | `databricks.account` | `host = "https://accounts.azuredatabricks.net"`, `account_id = get_env("DATABRICKS_ACCOUNT_ID")` |
| Workspace (catalogs, grants, policies, warehouses) | `databricks.workspace` | `host = "https://${dependency.databricks.outputs.workspace_url}"`, `azure_workspace_resource_id = dependency.databricks.outputs.id` |

The workspace (`databricks` unit) and Unity Catalog (`databricks-uc` unit) are separate Terragrunt units with separate state.
`infra/deployment/_envcommon/databricks-uc.hcl` generates both aliased providers from the `databricks` unit's outputs:

```hcl
generate "provider_databricks" {
  path      = "provider_databricks_gen.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "databricks" {
      alias      = "account"
      host       = "https://accounts.azuredatabricks.net"
      account_id = "${local.databricks_account_id}"   # get_env("DATABRICKS_ACCOUNT_ID")
    }
    provider "databricks" {
      alias                       = "workspace"
      host                        = "https://${dependency.databricks.outputs.workspace_url}"
      azure_workspace_resource_id = "${dependency.databricks.outputs.id}"
    }
  EOF
}
# auth: azure-cli locally, OIDC in CI (ARM_USE_OIDC + ARM_CLIENT_ID + ARM_TENANT_ID)
```

On a fresh environment the PR plan for `databricks-uc` runs against `mock_outputs` (fake workspace host), so it shows the
intended resources but cannot reach the workspace API; CI applies `databricks` first, then `databricks-uc` with real outputs.

## Workspace (VNet injection + SCC)

```hcl
resource "azurerm_databricks_workspace" "this" {
  name                                  = var.name
  resource_group_name                   = var.resource_group_name
  location                              = var.location
  sku                                   = "premium"
  managed_resource_group_name           = "rg-${var.name}-managed"
  public_network_access_enabled         = var.public_network_access_enabled
  network_security_group_rules_required = var.public_network_access_enabled ? "AllRules" : "NoAzureDatabricksRules"
  infrastructure_encryption_enabled     = true

  custom_parameters {
    no_public_ip                                         = true
    virtual_network_id                                   = var.virtual_network_id
    public_subnet_name                                   = var.host_subnet_name
    private_subnet_name                                  = var.container_subnet_name
    public_subnet_network_security_group_association_id  = var.host_subnet_nsg_association_id
    private_subnet_network_security_group_association_id = var.container_subnet_nsg_association_id
  }
  tags = var.tags
}
```

- Both subnets: delegation `Microsoft.Databricks/workspaces` with actions `Microsoft.Network/virtualNetworks/subnets/join/action`, `prepareNetworkPolicies/action`, `unprepareNetworkPolicies/action`; NSG associated; not shared.
- Private endpoints: `databricks_ui_api` (front-end + back-end), `browser_authentication` once per region; DNS zone `privatelink.azuredatabricks.net`.

## Unity Catalog

```hcl
resource "azurerm_databricks_access_connector" "uc" {
  name                = "dbac-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  identity { type = "SystemAssigned" }
}

resource "azurerm_role_assignment" "uc_blob" {
  scope                = azurerm_storage_container.uc.id   # or storage account
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.uc.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "databricks_metastore" "this" {
  provider      = databricks.account
  name          = "metastore-${var.region_short}"
  region        = var.location
  storage_root  = "abfss://${azurerm_storage_container.uc.name}@${azurerm_storage_account.uc.name}.dfs.core.windows.net/"
  force_destroy = false
}

resource "databricks_metastore_assignment" "this" {
  provider     = databricks.account
  metastore_id = databricks_metastore.this.id
  workspace_id = var.workspace_numeric_id   # azurerm_databricks_workspace.workspace_id
}

resource "databricks_storage_credential" "uc" {
  provider = databricks.workspace
  name     = "sc-${var.environment}"
  azure_managed_identity { access_connector_id = azurerm_databricks_access_connector.uc.id }
}
```

- One metastore per region per account. In most orgs it already exists - accept `metastore_id` as input and only create when `var.create_metastore = true`.
- Grants to account groups via `databricks_grants`; never to individual users.
- Note `workspace_id` (numeric) vs `id` (ARM resource ID) on `azurerm_databricks_workspace`.

## Cluster policy

```hcl
resource "databricks_cluster_policy" "jobs" {
  provider = databricks.workspace
  name     = "jobs-${var.environment}"
  definition = jsonencode({
    "autotermination_minutes" : { "type" : "range", "maxValue" : 60, "defaultValue" : 30 },
    "data_security_mode"      : { "type" : "allowlist", "values" : ["SINGLE_USER", "USER_ISOLATION"] },
    "node_type_id"            : { "type" : "allowlist", "values" : var.allowed_node_types },
    "custom_tags.cost_center" : { "type" : "fixed", "value" : var.tags["cost_center"] },
    "spark_version"           : { "type" : "regex", "pattern" : "1[4-9]\\.[0-9]+\\.x-scala.*" }
  })
}
```

## Pitfalls

- Changing anything in `custom_parameters` replaces the workspace (all notebooks/jobs/config lost) - CRITICAL.
- `sku` premium -> standard replaces; trial -> premium is in place.
- The CI identity must be Databricks account admin for account-level resources and workspace admin for workspace resources.
- Destroying a workspace with UC assignment: remove `databricks_metastore_assignment` first.
