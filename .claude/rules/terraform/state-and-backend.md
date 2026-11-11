---
paths:
  - "**/*.tf"
  - "**/backend*.hcl"
  - "infra/deployment/**"
---
# Terraform State and Backend

## Backend

- Every Terragrunt unit gets its backend from `infra/deployment/backend.hcl` (ri-iac ADR-005):

```hcl
remote_state {
  backend  = "azurerm"
  generate = { path = "backend_gen.tf", if_exists = "overwrite_terragrunt" }
  config = {
    subscription_id      = get_env("TFSTATE_SUBSCRIPTION_ID", get_env("ARM_SUBSCRIPTION_ID", ""))
    resource_group_name  = local.resource_group_name   # TFSTATE_RESOURCE_GROUP
    storage_account_name = local.storage_account_name  # TFSTATE_STORAGE_ACCOUNT
    container_name       = "tfstate"
    key                  = "${get_path_from_repo_root()}/terraform.tfstate"
    use_azuread_auth     = true
  }
}
```

- One state file per unit: key `infra/deployment/<env>/<unit>/terraform.tfstate`. Small blast radius, parallel plans, per-unit locks.
- The key is derived from the directory. Moving or renaming a unit directory points it at an empty state; plan will show a full recreate. Blocker until a state migration is planned and run in CI.
- `infra/bootstrap` (plain Terraform, local state, run once) creates the storage account with blob versioning, soft delete, `shared_access_key_enabled = false`, TLS 1.2, and a `CanNotDelete` lock. Terragrunt never bootstraps the backend (`--backend-bootstrap` is blocked).
- Locking is native (blob lease). Never use `-lock=false`.

## Access

- Engineers get `Storage Blob Data Reader` on the state container; plan identities need `Storage Blob Data Contributor` for the lease lock; only CI identities get write access.
- Plans in CI run with a separate identity per environment (`<env>-plan` GitHub Environment).

## Forbidden locally

`terraform|terragrunt state rm|mv|push|replace-provider`, `force-unlock`, `import`, `apply`, `destroy`, `taint`, `refresh`;
`terragrunt run [--all] [--] apply|destroy`, `run-all`, `apply-all`, `destroy-all`, `backend bootstrap|delete|migrate`.
These are blocked by `.claude/hooks-platform/guard-bash.py` (cases in `test_guard_bash.py`).

Use declarative alternatives in code reviewed via PR:

| Need | Use |
|------|-----|
| Rename / move address within a unit | `moved { from = ... to = ... }` in the module |
| Adopt existing resource | `import { to = ... id = ... }` |
| Stop managing a resource | `removed { from = ... lifecycle { destroy = false } }` |
| Force recreation | `terragrunt run -- plan -replace=ADDR` reviewed in PR, applied by CI |
| Move resources between units | `removed` (destroy = false) in the old unit + `import` in the new one, same PR |

## Cross-unit references

- Use Terragrunt `dependency` blocks (outputs of another unit) with `mock_outputs` for read-only commands only (`local.common.mock_commands`: init, validate, plan, providers, show). Never `terraform_remote_state`.
- Values that come from outside this repo (hub VNet, hub DNS zones) go in `<env>/env.hcl` or `data` sources.

## Never

- Commit `*.tfstate*`, `*.tfplan`, `.terraform/`, `.terragrunt-cache/`, `*_gen.tf`, or `crash.log`.
- Read or print state content in a Claude session (contains secrets in plain text).
