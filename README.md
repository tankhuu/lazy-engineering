# lazy-engineering
A desirable for Lazy Engineer in the Era of AI which leverage AI for Automation as much as we can with the power of AI Evolution.

This repo is a Claude Code harness for DevOps / Platform Engineers who build Azure infrastructure with Terragrunt + Terraform (AKS + Azure Databricks) in VS Code. It layers a Terragrunt/Terraform/Azure platform pack on top of [ECC](https://github.com/affaan-m/ECC) and ships a production-shaped scaffold whose environment layout follows backbase-rnd/ri-iac ADR-005 ("State Management (Terraform + Terragrunt)"). Our adoption and deliberate deviations are recorded in [ADR-0001](docs/adr/0001-adopt-terragrunt-per-ri-iac-adr-005.md); all decisions are indexed in [docs/adr](docs/adr/README.md).

## What's inside

| Path | Purpose |
|------|---------|
| `CLAUDE.md` | Project memory: layout, hard rules, workflow, conventions |
| `.claude/rules/{terraform,azure}/` | Path-scoped rules loaded when editing `*.tf` and `infra/deployment/**/*.hcl` (incl. `terraform/terragrunt.md`) |
| `.claude/agents/` | `terraform-architect`, `terraform-reviewer`, `terraform-plan-analyzer`, `aks-platform-engineer`, `databricks-platform-engineer`, `azure-security-reviewer` |
| `.claude/commands/` | `/tf-plan`, `/tf-review`, `/tf-module-new`, `/tf-drift`, `/aks-check`, `/dbx-check` (all Terragrunt-aware) |
| `.claude/skills/` | `terragrunt-azure`, `terraform-azure-patterns`, `aks-terraform`, `databricks-terraform`, `azure-landing-zone` |
| `.claude/hooks-platform/` | `guard-bash.py` (blocks apply/destroy/state for terraform and every terragrunt form, mutating az, kubectl, helm, databricks; cases in `test_guard_bash.py`) and `post-edit-tf.sh` (terraform fmt + tflint, terragrunt hcl fmt + `hcl validate --inputs`) |
| `.claude/settings.json` | Team permissions (allow/ask/deny), hooks, enabled MCP servers |
| `.mcp.json` | Read-only MCP servers: Terraform registry, Azure, Kubernetes, Databricks, Context7 |
| `ecc-install.json`, `ecc-keep.json`, `scripts/ecc_sync.py` | Reproducible ECC install, pruned to what platform work needs |
| `infra/bootstrap/` | Remote state storage (plain Terraform, run once, local state) |
| `infra/modules/` | `resource-groups`, `network`, `log-analytics`, `key-vault`, `acr`, `aks`, `databricks`, `databricks-uc` (each with `terraform test`) |
| `infra/deployment/` | Terragrunt live config: `backend.hcl`, `common.hcl`, `_envcommon/<unit>.hcl`, `<env>/env.hcl`, `<env>/<unit>/terragrunt.hcl`. dev = standalone spoke with NAT egress, prod = hub-connected and private-only |
| `.github/workflows/terraform.yml` | PR: fmt/validate/tflint/checkov/test + `terragrunt run --all plan` summary comment. main: `run --all apply` behind environment approval |
| `.vscode/` | Recommended extensions, Terraform LS + HCL settings, tasks |

ECC-managed files (`.claude/rules/ecc`, ECC agents/skills/commands, `.claude/settings.local.json`) are generated per machine and gitignored.

## Terragrunt layout

```
infra/deployment/
  backend.hcl            remote_state azurerm, key = infra/deployment/<env>/<unit>/terraform.tfstate
  common.hcl             CAF names, tags, version constraints, generated azurerm provider, PLATFORM_OFFLINE switch
  _envcommon/<unit>.hcl  module source, dependency blocks with mock_outputs, inputs
  dev/env.hcl  prod/env.hcl
  dev/<unit>/terragrunt.hcl  prod/<unit>/terragrunt.hcl     (three includes, identical across envs)
  tests/render_check.py
```

Units and order: `resource-groups -> network, log-analytics -> key-vault, acr -> aks`; `network, log-analytics -> databricks -> databricks-uc` (`make graph ENV=dev`).

Differences from ri-iac: subscription, tenant and Databricks account/metastore IDs come from environment variables (`get_env`) instead of being hardcoded in `common.hcl`, and per-component logic lives once in `_envcommon/` so unit files are identical across environments.

## Setup

1. Tools (macOS):

   ```bash
   brew install terraform terragrunt tflint terraform-docs checkov pre-commit azure-cli kubelogin kubectl jq node
   brew tap databricks/tap && brew install databricks
   npm install -g @anthropic-ai/claude-code
   ```

   Versions used in CI: Terraform 1.11.1, Terragrunt 1.1.6. Docker is needed for the Terraform MCP server.

2. Harness and hooks:

   ```bash
   make ecc-sync      # installs ECC into .claude/ and merges its hooks into settings.local.json
   make init-tools    # tflint plugins + pre-commit hooks
   ```

3. Azure and Databricks context (IDs come from the environment, never from code):

   ```bash
   az login && az account set --subscription <subscription>    # Makefile exports ARM_SUBSCRIPTION_ID / ARM_TENANT_ID from az
   export TFSTATE_RESOURCE_GROUP=<bootstrap rg> TFSTATE_STORAGE_ACCOUNT=<bootstrap storage account>
   export DATABRICKS_ACCOUNT_ID=<account-id>
   export DATABRICKS_METASTORE_ID=<regional-metastore-id>
   # Optional, for the Databricks MCP server:
   export DATABRICKS_HOST=https://adb-<id>.<n>.azuredatabricks.net DATABRICKS_TOKEN=<pat>
   ```

4. Open the folder in VS Code, install the recommended extensions, then run `claude` in the integrated terminal.

ECC's GateGuard asks for a short justification before Claude creates a new file. That is intended; set `ECC_GATEGUARD=off` only for bulk scaffolding sessions.

## First deployment

```bash
cp infra/bootstrap/terraform.tfvars.example infra/bootstrap/terraform.tfvars   # edit
terraform -chdir=infra/bootstrap init && terraform -chdir=infra/bootstrap apply   # run by a human, once
export TFSTATE_RESOURCE_GROUP=... TFSTATE_STORAGE_ACCOUNT=...                     # from bootstrap outputs
make validate ENV=dev                                                            # offline, mocked dependencies
make plan ENV=dev
```

Everything after bootstrap goes through pull requests. Claude sessions cannot run `apply`, `destroy`, `run --all apply` or state-mutating commands; the guard hook blocks them even if permissions are loosened.

## Daily workflow with Claude Code

| Ask Claude | What happens |
|------------|--------------|
| `/plan add a GPU node pool to AKS` | ECC planner + `terraform-architect` produce a phased plan (modules + Terragrunt wiring) |
| edit `infra/modules/**` | post-edit hook runs `terraform fmt` and `tflint`; findings come back to Claude |
| edit `infra/deployment/**/*.hcl` | post-edit hook runs `terragrunt hcl fmt` (+ `hcl validate --inputs` on unit files) |
| `/tf-module-new private-dns-resolver` | scaffolds a module with versions, variables, tests and README, and shows the Terragrunt unit wiring |
| `/tf-plan dev [aks]` | fmt, offline validate, tflint, checkov, tests, `terragrunt run --all plan`, risk summary from `terraform-plan-analyzer` |
| `/tf-review` | `terraform-reviewer` + `azure-security-reviewer` on the branch diff (incl. unit state-key safety) |
| `/tf-drift prod` | refresh-only plans per unit, classifies drift as expected / unexpected |
| `/aks-check dev`, `/dbx-check dev` | read-only health checks; names from `terragrunt render`, state from `make output UNIT=aks` |

Make targets (also exposed as VS Code tasks): `make fmt lint test validate validate-all graph docs lock`, `make plan ENV=<env> [UNIT=<unit>]`, `make drift ENV=<env>`, `make output ENV=<env> UNIT=<unit>`.

## CI (GitHub Actions)

`.github/workflows/terraform.yml` authenticates with Azure OIDC (no client secrets) and installs a pinned, checksum-verified Terragrunt. Configure:

- Repository variables: `AZURE_TENANT_ID`, `DATABRICKS_ACCOUNT_ID`, `TFSTATE_SUBSCRIPTION_ID`, `TFSTATE_RESOURCE_GROUP`, `TFSTATE_STORAGE_ACCOUNT`.
- Environments `dev-plan`, `prod-plan` (no reviewers) and `dev`, `prod` (required reviewers), each with variables `AZURE_CLIENT_ID`, `AZURE_SUBSCRIPTION_ID`, `DATABRICKS_METASTORE_ID`.
- Federated credentials on each app registration for `repo:<org>/<repo>:environment:<name>`.

Pull requests get a per-unit plan summary comment per environment (stateful destroys/replacements flagged). Merging to `main` runs a pre-apply plan, refuses to continue on stateful destroy/replace, then `terragrunt run --all apply` for dev, then prod after approval.

## Updating ECC

```bash
make ecc-sync      # uses $ECC_HOME, else the Claude plugin cache, else clones to ~/.cache/ecc
git status .claude # only platform files should show up
```

To add an ECC agent, skill, command or rule set, add it to `ecc-keep.json` and rerun `make ecc-sync`.

## Safety model

| Layer | Enforces |
|-------|----------|
| `CLAUDE.md` + rules | What Claude should do |
| `settings.json` permissions | Deny apply/destroy/state (terraform and terragrunt) and reads of state, plan binaries, `.terragrunt-cache`, `.env`, kubeconfig, Azure/Databricks credentials; ask before `git push` and cluster credentials |
| `guard-bash.py` PreToolUse hook | Parses every Bash command (including `bash -c`, heredocs fed to shells, `terragrunt exec --`) and blocks mutating terraform/terragrunt/az/kubectl/helm/databricks verbs |
| Read-only MCP servers | Azure `--read-only`, Kubernetes `read_only` + `disable_destructive` |
| CI + environment approvals | The only path that changes Azure; apply refuses stateful destroy/replace |
