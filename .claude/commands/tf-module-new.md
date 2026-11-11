---
description: Scaffold a new Terraform module under infra/modules/<name> following repo conventions (versions, variables with validation, outputs, mock-provider tests, terraform-docs README).
argument-hint: "<module-name> [short purpose]"
---

# /tf-module-new

Module: first word of `$ARGUMENTS` (kebab-case). Purpose: the rest.

## Steps

1. Refuse if `infra/modules/<name>` exists. Ask **terraform-architect** for a contract (inputs, outputs, RBAC) if the purpose spans more than one Azure service.
2. Check whether an Azure Verified Module fits (`terraform` MCP: search `Azure/avm-res-*`). If yes, propose wrapping/pinning it instead and wait for confirmation.
3. Create:
   ```
   infra/modules/<name>/
     versions.tf      # required_version >= 1.9, azurerm ~> 5.13 (copy constraints from infra/modules/network/versions.tf)
     variables.tf     # name, location, resource_group_name, tags + module-specific; types, descriptions, validations
     main.tf          # resources; tags = var.tags; public access off; diagnostic settings when supported
     outputs.tf       # id, name + what callers need; sensitive where relevant
     tests/<name>.tftest.hcl   # mock_provider "azurerm" {}; assertions for naming, public access, tags; one expect_failures
     README.md        # header + terraform-docs markers
   ```
   README markers:
   ```
   <!-- BEGIN_TF_DOCS -->
   <!-- END_TF_DOCS -->
   ```
4. Run `terraform fmt`, `terraform -chdir=infra/modules/<name> init -backend=false && terraform -chdir=infra/modules/<name> validate`, `terraform -chdir=infra/modules/<name> test`, `make docs`.
5. Show the Terragrunt wiring but do not create it unless asked (skill `terragrunt-azure`, "Add a unit"):
   `infra/deployment/_envcommon/<name>.hcl` (source `${get_repo_root()}/infra/modules/<name>`, dependency blocks with
   `mock_outputs`, inputs), new values in each `infra/deployment/<env>/env.hcl`, and the three-include `terragrunt.hcl` in
   `infra/deployment/<env>/<name>/` for every env.
