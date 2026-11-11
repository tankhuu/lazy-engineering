---
name: terragrunt-azure
description: Terragrunt live layout for the Azure platform (infra/deployment, backbase-rnd/ri-iac ADR-005). Use when adding or changing a unit, an environment, a dependency between units, generated providers, remote state, or when running terragrunt plan/validate/render/output. Covers safe CLI usage (apply is CI-only), mock_outputs, offline validation and state-key rules.
---

# Terragrunt on Azure (ri-iac ADR-005 layout)

Terraform modules in `infra/modules/*` stay plain Terraform (tests, tflint, terraform-docs). Terragrunt only
wires them per environment in `infra/deployment`. Source of the pattern: `backbase-rnd/ri-iac`
`azure/docs/ARCHITECTURE_DECISIONS.md` ADR-005 "State Management (Terraform + Terragrunt)".

## When to use

- Adding a component (unit) to an environment, or a new environment.
- Passing outputs between components (`dependency` blocks), provider generation, backend changes.
- Running or interpreting `terragrunt run --all plan`, `render`, `hcl validate --inputs`, `output`.

## Layout

```
infra/deployment/
  backend.hcl              remote_state azurerm, key = <unit path from repo root>/terraform.tfstate
  common.hcl               shared locals: CAF names, tags, subnet/DNS maps, offline switch; generates provider "azurerm"
  _envcommon/<unit>.hcl    per-component wiring: terraform.source, dependency blocks + mock_outputs, inputs
  <env>/env.hcl            per-env values only (CIDRs, SKUs, sizes, hub IDs); replaces terraform.tfvars
  <env>/<unit>/terragrunt.hcl   3 includes, identical in every env; directory name selects _envcommon/<unit>.hcl
  tests/render_check.py    offline wiring assertions (make test-wiring)
```

Units today: `resource-groups -> network, log-analytics -> key-vault, acr -> aks, databricks -> databricks-uc`
(`make graph ENV=dev`). Each unit has its own state file and `.terraform.lock.hcl`.

| ri-iac ADR-005 | Here | Note |
|---|---|---|
| `deployment/common.hcl` | `infra/deployment/common.hcl` | IDs from env, not hardcoded (CLAUDE.md hard rule) |
| `deployment/backend.hcl` | `infra/deployment/backend.hcl` | same key scheme, `use_azuread_auth = true` |
| `deployment/<env>/env.hcl` | `infra/deployment/<env>/env.hcl` | |
| `<env>/<component>/terragrunt.hcl` | same, plus `_envcommon/` | DRY: units are 3 includes, logic lives once |
| `dependency` + `mock_outputs` | same | mocks allowed for read-only commands only (`common.hcl` `mock_commands`) |

## Rules

1. Units contain only the three includes. Behaviour goes in `_envcommon/<unit>.hcl`, values in `<env>/env.hcl`.
   `diff -r infra/deployment/dev infra/deployment/prod` must show only `env.hcl` and lock-file differences.
2. Names and tags come from `common.hcl` locals. Modules never invent names.
3. Never hardcode subscription, tenant, object or account IDs. Use `get_env()`: `ARM_SUBSCRIPTION_ID`,
   `ARM_TENANT_ID`, `DATABRICKS_ACCOUNT_ID`, `DATABRICKS_METASTORE_ID`, `TFSTATE_*`. Placeholders only when
   `PLATFORM_OFFLINE=true`.
4. Every `dependency` has `mock_outputs` with realistic Azure resource IDs (they must pass module validation),
   `mock_outputs_allowed_terraform_commands = local.common.mock_commands` (init, validate, plan, providers, show) and
   `skip_outputs = local.common.offline`. Never allow mocks for `apply`/`destroy`/`import`/`refresh`; `render_check.py` asserts it.
   A command missing from the list gets no outputs at all when the upstream has no state (e.g. `providers lock` fails).
5. Ordering-only edges use `dependencies { paths = [...] }`; value edges use `dependency`.
6. Provider blocks are generated (`generate "provider_*"`, `if_exists = "overwrite_terragrunt"`); `required_providers`
   stays in the module's `versions.tf` (duplicates are an error). Provider config that needs another unit's outputs
   (Databricks workspace host) is generated in the consuming `_envcommon` file.
7. The state key is the unit path. Renaming or moving a unit directory starts an empty state and Terraform will plan to
   recreate everything. Treat it like a destroy/replace of stateful resources: blocker, migrate state in CI first.
8. Pin `terraform_version_constraint` and `terragrunt_version_constraint` in `common.hcl`; CI installs pinned,
   checksum-verified binaries.

## Gotchas

- `locals` cannot reference `dependency.*`; use them in `inputs` or `generate` only.
- HCL conditionals evaluate both branches; use `try()`/`lookup()` for maps that may be null (see the DNS-zone lookups).
- `include` with `expose = true` is needed to read `include.common.locals`; `_envcommon` files read `common.hcl` via
  `read_terragrunt_config(find_in_parent_folders("common.hcl"))`.
- In `common.hcl`, `get_original_terragrunt_dir()` is the unit dir (env.hcl is `../env.hcl`).
- `terragrunt run --all apply` adds `-auto-approve` automatically. That is why every apply form is CI-only.
- Shallow merge: a child `inputs` key overrides the same key from `common.hcl`.
- `.terragrunt-cache/` holds copied modules, generated files and plan files. Never read plans or state from it.

## Commands

Allowed locally (read-only):

```bash
make validate ENV=dev                 # hcl validate --inputs + offline init/validate on every unit
make test                             # module tftests + render_check.py + guard cases
make graph ENV=dev                    # terragrunt dag graph
make plan ENV=dev [UNIT=aks]          # run --all plan -> .plans/dev/**/*.json
make drift ENV=dev                    # refresh-only plan, exit 2 = drift
make output ENV=dev UNIT=aks          # terragrunt output -json for one unit
terragrunt render --format json --working-dir infra/deployment/dev/aks   # resolved inputs, no Azure access with PLATFORM_OFFLINE=true
```

CI-only (blocked by `.claude/hooks-platform/guard-bash.py`): `terragrunt apply|destroy|import|force-unlock|refresh|taint`,
`run [--all] [--] apply|destroy`, `run-all`, `apply-all`, `destroy-all`, `state rm|mv|push`, `backend bootstrap|delete|migrate`,
`--backend-bootstrap`, `-lock=false`, `exec -- <mutating cmd>`.

## Add a unit

1. Module in `infra/modules/<name>` with tests (`/tf-module-new`).
2. `_envcommon/<name>.hcl`: `terraform { source = "${get_repo_root()}/infra/modules/<name>" }`, dependencies with mocks, inputs.
3. New values in every `<env>/env.hcl`.
4. Same `terragrunt.hcl` (copy of any unit) in `infra/deployment/<env>/<name>/` for every env.
5. Extend `UNITS` and the invariants in `infra/deployment/tests/render_check.py`.
6. `make lock`, `make validate-all`, `make test`, then `/tf-plan dev`.

## Add an environment

Copy `infra/deployment/dev` to `infra/deployment/<env>`, edit only `env.hcl` (unique CIDRs, hub IDs, sizes), run `make lock`,
add `<env>-plan` and `<env>` GitHub Environments and the matrix entry in `.github/workflows/terraform.yml`.

## Related

`terraform-azure-patterns` (module HCL), `aks-terraform`, `databricks-terraform`, `azure-landing-zone`,
`.claude/rules/terraform/terragrunt.md`, `/tf-plan`, `/tf-drift`, `/tf-review`.
