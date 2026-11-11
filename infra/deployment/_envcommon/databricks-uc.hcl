# Unit: Unity Catalog (access connector, ADLS, external location, catalogs, cluster policy).
# Included by <env>/databricks-uc/terragrunt.hcl. Generates the account- and workspace-level
# databricks providers because the workspace host is only known from the databricks unit.

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  env    = local.common.env

  databricks_account_id   = get_env("DATABRICKS_ACCOUNT_ID", local.common.offline ? "11111111-1111-1111-1111-111111111111" : "")
  databricks_metastore_id = get_env("DATABRICKS_METASTORE_ID", local.common.offline ? "22222222-2222-2222-2222-222222222222" : "")
}

terraform {
  source = "${get_repo_root()}/infra/modules/databricks-uc"
}

dependency "network" {
  config_path  = "${get_terragrunt_dir()}/../network"
  skip_outputs = local.common.offline

  mock_outputs = {
    subnet_ids           = { (local.common.subnet_names.private_endpoints) = local.common.mock_subnet }
    private_dns_zone_ids = local.common.mock_dns_zone_ids
  }
  mock_outputs_allowed_terraform_commands = local.common.mock_commands
}

dependency "databricks" {
  config_path  = "${get_terragrunt_dir()}/../databricks"
  skip_outputs = local.common.offline

  mock_outputs = {
    id            = "${local.common.mock_rg}/providers/Microsoft.Databricks/workspaces/dbw-mock"
    workspace_id  = "1234567890123456"
    workspace_url = "adb-1234567890123456.7.azuredatabricks.net"
  }
  mock_outputs_allowed_terraform_commands = local.common.mock_commands
}

# Auth: Azure CLI locally, ARM_USE_OIDC + ARM_CLIENT_ID in CI (github-oidc-azure).
generate "provider_databricks" {
  path      = "provider_databricks_gen.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "databricks" {
      alias      = "account"
      host       = "https://accounts.azuredatabricks.net"
      account_id = "${local.databricks_account_id}"
    }

    provider "databricks" {
      alias                       = "workspace"
      host                        = "https://${dependency.databricks.outputs.workspace_url}"
      azure_workspace_resource_id = "${dependency.databricks.outputs.id}"
    }
  EOF
}

inputs = {
  environment           = local.env.environment
  resource_group_name   = local.common.resource_groups.databricks
  access_connector_name = local.common.names.dbac
  storage_account_name  = local.common.names.st_uc
  workspace_id          = dependency.databricks.outputs.workspace_id
  catalogs              = local.env.databricks.catalogs

  metastore = {
    create = false
    id     = local.databricks_metastore_id
  }

  private_endpoint = {
    enabled   = true
    subnet_id = dependency.network.outputs.subnet_ids[local.common.subnet_names.private_endpoints]
    private_dns_zone_ids = {
      blob = try(local.env.hub_private_dns_zone_ids["blob"], dependency.network.outputs.private_dns_zone_ids[local.common.private_dns_zone_names.blob])
      dfs  = try(local.env.hub_private_dns_zone_ids["dfs"], dependency.network.outputs.private_dns_zone_ids[local.common.private_dns_zone_names.dfs])
    }
  }
}
