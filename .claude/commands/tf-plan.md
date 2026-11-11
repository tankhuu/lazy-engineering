---
description: Run the quality gate and a read-only Terragrunt plan for one environment (all units or one), then summarise risk with terraform-plan-analyzer. Never applies.
argument-hint: "<env: dev|prod> [unit, e.g. aks] [extra plan args, e.g. -target=azurerm_kubernetes_cluster.this]"
---

# /tf-plan

Arguments: `$ARGUMENTS`. First word is the env (default `dev`), optional second word a unit under `infra/deployment/<env>/`.
Working dir: `infra/deployment/<env>` (Terragrunt, ri-iac ADR-005 layout; skill `terragrunt-azure`).

## Steps

1. Preconditions
   - `az account show --query "{sub:name, id:id, tenant:tenantId, user:user.name}" -o table` - confirm the subscription matches the env (`infra/deployment/<env>/env.hcl` comments, team docs). Stop and ask if it does not.
   - `TFSTATE_RESOURCE_GROUP` / `TFSTATE_STORAGE_ACCOUNT` (defaults in `infra/deployment/backend.hcl`) point at the bootstrap storage. Databricks units need `DATABRICKS_ACCOUNT_ID` and `DATABRICKS_METASTORE_ID` in the environment; ask the user if they are missing, never invent them.
2. Static gate, offline (stop on first failure and fix or report):
   ```bash
   make fmt-check
   make validate ENV=<env>     # terragrunt hcl validate --inputs + terraform validate on every unit, mocked dependencies
   make tflint
   make checkov
   make test                   # module tftests + render_check.py + guard cases
   ```
3. Plan (read-only, real dependency outputs where the upstream unit has state; mocks otherwise):
   ```bash
   make plan ENV=<env>                 # all units: terragrunt run --all plan --out-dir/--json-out-dir .plans/<env>
   make plan ENV=<env> UNIT=<unit>     # one unit -> .plans/<env>/<unit>.json
   ```
   Extra plan args: `terragrunt run --working-dir infra/deployment/<env>/<unit> -- plan -input=false -lock-timeout=5m -out=$PWD/.plans/<env>/<unit>.tfplan <extra args>`
   then `terragrunt run --working-dir infra/deployment/<env>/<unit> -- show -json $PWD/.plans/<env>/<unit>.tfplan > .plans/<env>/<unit>.json`.
4. Summarise: `python3 .github/scripts/plan_summary.py .plans/<env> --env <env>` (per-unit counts, destroy/replace list, stateful flag).
   Delegate the per-unit JSON under `.plans/<env>` to the **terraform-plan-analyzer** agent.
5. Note units whose plan used `mock_outputs` (warning "has no outputs, but mock outputs provided"): their upstream is not applied yet, so IDs in that plan are placeholders. CI applies in dependency order with real outputs.
6. Report: gate results, per-unit plan summary table, CRITICAL/HIGH findings, recommendation. Remind that apply happens only via CI after merge.
7. Clean up: `rm -rf .plans/<env>` unless the user asks to keep it (gitignored). Never `cat`/`strings` the binary `*.tfplan` files.

## Never

`terragrunt apply`, `terragrunt run --all apply` (auto-approves), `destroy`, `-lock=false`, `--backend-bootstrap`, reading `*.tfstate` or `.terragrunt-cache/**`. The guard hook blocks these anyway.
