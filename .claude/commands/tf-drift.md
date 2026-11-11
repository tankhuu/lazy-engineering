---
description: Detect drift between Terraform state and real Azure resources for an environment using refresh-only Terragrunt plans per unit. Read-only.
argument-hint: "<env: dev|prod> [unit]"
---

# /tf-drift

Arguments: `$ARGUMENTS` (env default `dev`, optional unit).

## Steps

1. Same preconditions as `/tf-plan` (correct subscription, state storage env vars, Databricks IDs).
2. Run:
   ```bash
   make drift ENV=<env>     # terragrunt run --all --json-out-dir .plans/<env>/drift -- plan -refresh-only -detailed-exitcode
   ```
   One unit:
   ```bash
   terragrunt run --working-dir infra/deployment/<env>/<unit> -- plan -refresh-only -input=false -lock-timeout=5m -out=$PWD/.plans/<env>/<unit>-drift.tfplan
   terragrunt run --working-dir infra/deployment/<env>/<unit> -- show -json $PWD/.plans/<env>/<unit>-drift.tfplan > .plans/<env>/<unit>-drift.json
   ```
   Exit code 0 / "No changes" for every unit => no drift; report and stop. Exit code 2 => drift in at least one unit.
3. Hand the drift JSON under `.plans/<env>/drift` to **terraform-plan-analyzer** (focus on `.resource_drift`), grouped by unit.
4. For each drifted resource classify:
   - **Expected** (autoscaler node counts, AKS auto-upgrade versions, Azure-managed tags, Databricks-managed NSG rules) -> recommend `lifecycle.ignore_changes` in the module with a comment, if not already present.
   - **Out-of-band change** (portal/CLI edits) -> recommend reverting via normal plan/apply in CI, or codifying the change in the module / `env.hcl`.
   - **Deleted outside Terraform** -> CRITICAL; recommend recreate via CI or `removed` block.
5. Optionally cross-check with the `azure` MCP / `az resource show --ids <id>` for evidence.
6. `rm -rf .plans/<env>/drift`. Never run `apply -refresh-only` (any form); state updates happen in CI.
