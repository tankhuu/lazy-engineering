# Remote state for every unit (layout from backbase-rnd/ri-iac ADR-005).
# Storage is created once by infra/bootstrap. The key is the unit path from the repo root, so each
# unit has its own state file: infra/deployment/<env>/<unit>/terraform.tfstate.
# Names are not secrets; the subscription comes from the environment, never from code.

locals {
  resource_group_name  = get_env("TFSTATE_RESOURCE_GROUP", "rg-tfstate-plat-weu")
  storage_account_name = get_env("TFSTATE_STORAGE_ACCOUNT", "stplattfstateweu01")
  container_name       = "tfstate"
}

remote_state {
  backend = "azurerm"

  generate = {
    path      = "backend_gen.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    subscription_id      = get_env("TFSTATE_SUBSCRIPTION_ID", get_env("ARM_SUBSCRIPTION_ID", ""))
    resource_group_name  = local.resource_group_name
    storage_account_name = local.storage_account_name
    container_name       = local.container_name
    key                  = "${get_path_from_repo_root()}/terraform.tfstate"
    use_azuread_auth     = true
  }
}
