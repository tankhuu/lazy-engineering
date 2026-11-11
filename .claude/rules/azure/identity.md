---
paths:
  - "**/*.tf"
---
# Azure Identity

## Principles

- No client secrets or certificates for automation. Use, in order of preference:
  1. Managed identity (user-assigned when the identity outlives one resource or needs pre-created RBAC)
  2. Workload identity federation (AKS pods, GitHub Actions OIDC)
  3. Service principal with federated credential
- Least privilege, narrowest scope, data-plane roles over control-plane roles (`Key Vault Secrets User` instead of `Key Vault Administrator`).

## Terraform / CI

- Local: `az login`, provider uses Azure CLI auth (`ARM_USE_CLI=true` default). Engineers have read-only roles on prod.
- CI: GitHub Actions OIDC (`ARM_USE_OIDC=true`, `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID` from environment variables, not secrets). Separate federated credentials for `pull_request` (plan, Reader + state Blob Reader) and `environment:<env>` (apply).
- Never `azurerm_role_assignment` with `Owner` from a module. `User Access Administrator` only in the bootstrap/landing-zone layer with conditions (ABAC) limiting assignable roles.

## AKS

- `oidc_issuer_enabled = true`, `workload_identity_enabled = true`.
- Entra ID integration: `azure_active_directory_role_based_access_control { azure_rbac_enabled = true }`, `local_account_disabled = true`.
- Kubelet identity gets `AcrPull` on the ACR only. Control-plane identity is user-assigned and gets `Network Contributor` on the AKS subnet only (when using BYO VNet).
- Pods: `azurerm_federated_identity_credential` per service account (`system:serviceaccount:<ns>:<sa>`) bound to a user-assigned identity.

## Databricks

- Unity Catalog storage via `azurerm_databricks_access_connector` (system- or user-assigned identity) with `Storage Blob Data Contributor` on the UC container only.
- Workspace provider auth: `azure_workspace_resource_id` + Azure CLI/OIDC; no PATs in Terraform. Account-level provider (`host = "https://accounts.azuredatabricks.net"`) uses the same Entra identity, which must be a Databricks account admin.
- Clusters access data through UC external locations, not mounted storage keys.

## Review checklist

- [ ] Any new `azurerm_role_assignment`: scope, role, principal type justified
- [ ] No `client_secret`, `password`, `access_key` arguments with literal values
- [ ] Federated credential subjects are exact (no wildcards)
