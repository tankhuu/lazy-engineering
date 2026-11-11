---
paths:
  - "infra/deployment/**/*.hcl"
  - "infra/deployment/**"
---
# Terragrunt (infra/deployment)

Layout and wiring follow backbase-rnd/ri-iac ADR-005; details and examples in the `terragrunt-azure` skill.

- `<env>/<unit>/terragrunt.hcl` holds only the `backend`, `common` and `envcommon` includes and is identical across envs.
- Wiring (`terraform.source`, `dependency`, `inputs`, extra `generate`) lives in `_envcommon/<unit>.hcl`; values live in `<env>/env.hcl`.
- `dependency` blocks: realistic `mock_outputs`, `mock_outputs_allowed_terraform_commands = local.common.mock_commands` (init, validate, plan, providers, show), `skip_outputs = local.common.offline`. Never allow mocks for apply/destroy/import/refresh (`make test-wiring` fails).
- No IDs in HCL. Use `get_env("ARM_TENANT_ID")`, `get_env("DATABRICKS_ACCOUNT_ID")`, `get_env("DATABRICKS_METASTORE_ID")`, `TFSTATE_*`.
- `required_providers` stays in module `versions.tf`; generated files contain provider blocks only.
- Renaming/moving a unit directory changes its state key: blocker until a state migration is planned in CI.
- After edits: `make validate ENV=<env>` and `make test-wiring`. The post-edit hook runs `terragrunt hcl fmt` and, for unit files, `hcl validate --inputs`.
- Never run any apply/destroy/state-mutating Terragrunt command locally; `run --all apply` auto-approves.
