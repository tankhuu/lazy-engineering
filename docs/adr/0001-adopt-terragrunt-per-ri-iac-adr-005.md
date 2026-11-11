# ADR-0001: Adopt Terragrunt per ri-iac ADR-005

**Date**: 2026-11-11
**Status**: accepted
**Deciders**: Platform team (tank)

## Context

`infra/envs/<env>` was one Terraform root module per environment: a single state file held the network, Key Vault,
ACR, AKS, Databricks workspace and Unity Catalog, so every plan locked and refreshed everything and any mistake had the
whole environment as blast radius. `dev` and `prod` were kept in sync by copying `.tf` files by hand. The Backbase
reference implementation (ri-iac, `azure/docs/ARCHITECTURE_DECISIONS.md`, ADR-005 "State Management (Terraform +
Terragrunt)") already standardises a Terragrunt layout with one state file per component.

## Decision

We use Terragrunt with the ri-iac ADR-005 layout under `infra/deployment/`: `backend.hcl` (azurerm backend, key
`${get_path_from_repo_root()}/terraform.tfstate`), `common.hcl`, `<env>/env.hcl` and one unit per component in
`<env>/<component>/terragrunt.hcl`, wired with `dependency` blocks. Reusable code stays in `infra/modules/*`.

Deliberate deviations from ri-iac:

1. Subscription, tenant and Databricks account/metastore IDs come from environment variables (`get_env`), never
   hardcoded in `common.hcl`.
2. An `_envcommon/<component>.hcl` layer holds source, dependencies and inputs, so every unit file is three includes
   and `dev`/`prod` differ only in `env.hcl`.
3. Offline mode (`PLATFORM_OFFLINE=true`): dependencies return `mock_outputs` and IDs fall back to placeholders, so
   validate, pre-commit and the CI static job run without Azure. Mocks are limited to read-only commands
   (`common.hcl` `mock_commands`); `make test-wiring` fails if apply/destroy/import/refresh are added.
4. Apply runs only in CI after merge, behind environment approval and a pre-apply plan that fails on destroy/replace of
   stateful resources (`plan_summary.py --fail-on-stateful`). Local apply/destroy is blocked by the PreToolUse hook.
5. `.terraform.lock.hcl` is committed per unit (linux_amd64 + darwin) and CI inits with `-lockfile=readonly`.

## Alternatives Considered

### Alternative 1: Plain Terraform, one root per environment (status quo)
- **Pros**: one tool, simple mental model, single plan per environment
- **Cons**: one large state per environment, slow plans, wide blast radius, manual dev/prod copy
- **Why not**: does not follow ri-iac ADR-005 and the blast radius grows with every component

### Alternative 2: Terraform workspaces per environment
- **Pros**: no extra tool, shared code across environments
- **Cons**: still one state per environment, environment selected by hidden CLI state, easy to plan the wrong workspace
- **Why not**: keeps the monolithic state and makes the target environment implicit

### Alternative 3: Terragrunt stacks (`terragrunt.stack.hcl`)
- **Pros**: generates units from a single stack file, less per-unit boilerplate
- **Cons**: newer feature, generated `.terragrunt-stack/` directories, diverges from the ri-iac layout
- **Why not**: ri-iac ADR-005 uses explicit units; `_envcommon` already removes most boilerplate

### Alternative 4: HCP Terraform / Terraform Cloud workspaces
- **Pros**: managed runs, state, policy and run tasks
- **Cons**: extra SaaS and licensing, state leaves the Azure subscription, separate identity model
- **Why not**: state must stay in our Azure storage with Entra ID auth; CI with OIDC already covers runs

## Consequences

### Positive
- Each component has its own state: smaller plans, smaller lock scope and blast radius
- `dev` and `prod` share identical unit code; only `env.hcl` differs
- Validation and wiring checks (`make validate`, `make test`) run offline, locally and in CI
- Layout matches ri-iac, so engineers move between repos without relearning it

### Negative
- Terragrunt is an extra required tool (pinned `>= 1.1.0, < 2.0.0`; CI installs 1.1.6 with checksum verification)
- Plans are per unit; CI aggregates them into one PR summary
- Cross-unit changes need dependency ordering and mock outputs kept realistic

### Risks
- Renaming or moving a unit directory changes its state key, which plans as destroy + create. Mitigation: treated as a
  blocker; migrate state in a reviewed CI change instead.
- Mock outputs could mask real wiring errors. Mitigation: mocks only for read-only commands, real `run --all plan`
  in CI on every PR.
- `run --all apply` auto-approves. Mitigation: only CI runs it, after environment approval and the stateful gate.
