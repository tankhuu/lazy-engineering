# Unit: resource groups. Included by infra/deployment/<env>/resource-groups/terragrunt.hcl.

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/infra/modules/resource-groups"
}

inputs = {
  resource_groups = local.common.resource_groups
}
