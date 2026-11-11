---
description: Review Terraform module and Terragrunt changes on the current branch (HCL quality, wiring, state safety, Azure security) using terraform-reviewer and azure-security-reviewer in parallel.
argument-hint: "[path or git range, default origin/main...HEAD]"
---

# /tf-review

Scope: `$ARGUMENTS` or, if empty, `git diff --name-only origin/main...HEAD -- infra` (fall back to uncommitted changes).

## Steps

1. List changed directories: modules (unique parents of changed `*.tf`, `*.tftest.hcl`) and Terragrunt (changed `infra/deployment/**/*.hcl`).
   A change to `common.hcl`, `backend.hcl` or `_envcommon/<unit>.hcl` affects every env; a change to `<env>/env.hcl` affects all units of that env.
   Run `make validate-all` and `make test-wiring` once for the whole set.
2. Launch in parallel:
   - **terraform-reviewer** with the directory list (it also checks Terragrunt wiring and state-key safety: renamed/moved unit directories).
   - **azure-security-reviewer** with the same scope.
   - If `infra/modules/aks` or AKS arguments changed: **aks-platform-engineer** in review mode.
   - If `infra/modules/databricks*` changed: **databricks-platform-engineer** in review mode.
3. Merge findings, deduplicate, sort CRITICAL > HIGH > MEDIUM > LOW, keep `file:line`.
4. Check docs: if module interfaces changed, run `make docs` and report whether READMEs changed.
5. Final verdict: BLOCK if any CRITICAL, REQUEST CHANGES if any HIGH, else APPROVE. Offer to apply fixes for findings that have concrete patches.
