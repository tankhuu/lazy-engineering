# Unit: Azure Container Registry (Premium, private endpoint). Included by <env>/acr/terragrunt.hcl.

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  env    = local.common.env
}

terraform {
  source = "${get_repo_root()}/infra/modules/acr"
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

dependency "log_analytics" {
  config_path  = "${get_terragrunt_dir()}/../log-analytics"
  skip_outputs = local.common.offline

  mock_outputs = {
    id = "${local.common.mock_rg}/providers/Microsoft.OperationalInsights/workspaces/log-mock"
  }
  mock_outputs_allowed_terraform_commands = local.common.mock_commands
}

inputs = {
  name                     = local.common.names.acr
  resource_group_name      = local.common.resource_groups.shared
  georeplication_locations = local.env.acr.georeplication_locations

  private_endpoint = {
    enabled   = true
    subnet_id = dependency.network.outputs.subnet_ids[local.common.subnet_names.private_endpoints]
    private_dns_zone_id = try(
      local.env.hub_private_dns_zone_ids["acr"],
      dependency.network.outputs.private_dns_zone_ids[local.common.private_dns_zone_names.acr],
    )
  }

  diagnostics = {
    enabled                    = true
    log_analytics_workspace_id = dependency.log_analytics.outputs.id
  }
}
