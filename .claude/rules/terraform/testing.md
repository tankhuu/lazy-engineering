---
paths:
  - "**/*.tf"
  - "**/*.tftest.hcl"
---
# Terraform Testing

> Extends [ecc/common/testing.md](../ecc/common/testing.md). Infra "tests first" means: write the `.tftest.hcl` assertions describing the contract of the module before or alongside the resources.

## Quality gate (same order locally, in pre-commit, and CI)

1. `terraform fmt -check` (modules, bootstrap) + `terragrunt hcl fmt --check` (infra/deployment)
2. `terraform validate` per module; per Terragrunt unit offline: `terragrunt hcl validate --inputs` + `run --all -- init -backend=false` + `validate` with `PLATFORM_OFFLINE=true` (dependencies return `mock_outputs`)
3. `tflint --recursive` on modules and bootstrap (azurerm ruleset)
4. `checkov` on modules and bootstrap (`.checkov.yaml`); in CI also on the per-unit plan JSON
5. `terraform test` per module (plan-mode, mocked providers)
6. `infra/deployment/tests/render_check.py`: renders every unit offline and asserts names, tags, state keys and hub/standalone wiring (replaces env-root tftests)
7. `terragrunt run --all plan` per env (CI on PRs, or locally against your own `az login`, read-only)

`make lint` runs 1, 3, 4; `make validate-all` runs 2; `make test` runs 5, 6 and the guard-hook cases; `make plan ENV=<env>` runs 7.

## Module tests

- Every module has `tests/<module>.tftest.hcl` with `command = plan` runs and `mock_provider "azurerm" {}` so tests run without Azure credentials.
- Assert the contract, not the implementation: names follow convention, public access disabled, tags present, required outputs non-null, validation rejects bad input (`expect_failures`).
- Use `override_data` / `override_resource` for values only known after apply.

Example:

```hcl
mock_provider "azurerm" {}

variables {
  name     = "kv-plat-dev-weu-01"
  location = "westeurope"
  # ...
}

run "public_access_disabled" {
  command = plan
  assert {
    condition     = azurerm_key_vault.this.public_network_access_enabled == false
    error_message = "Key Vault must not be publicly reachable."
  }
}

run "rejects_bad_env" {
  command         = plan
  variables { environment = "qa1" }
  expect_failures = [var.environment]
}
```

## Integration tests

- Optional `apply`-mode tests or Terratest run only in a dedicated sandbox subscription from CI, never from a local Claude session.

## Plan review

- Every PR plan is summarised by `terraform-plan-analyzer`: counts of create/update/replace/destroy and an explicit list of destroys/replaces on stateful resources.
