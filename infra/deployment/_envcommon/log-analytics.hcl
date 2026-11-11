# Unit: Log Analytics workspace. Included by <env>/log-analytics/terragrunt.hcl.

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/infra/modules/log-analytics"
}

dependencies {
  paths = ["${get_terragrunt_dir()}/../resource-groups"]
}

inputs = {
  name                = local.common.names.log
  resource_group_name = local.common.resource_groups.shared
  retention_in_days   = local.common.env.log_analytics.retention_in_days
}
