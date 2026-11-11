---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
  - "infra/deployment/**/*.hcl"
---
# Terraform Security (Azure)

> Extends [ecc/common/security.md](../ecc/common/security.md).

## Secrets

- No secrets, keys, connection strings, SAS tokens, subscription/tenant/account IDs in `.tf`, committed `.tfvars`, or Terragrunt `.hcl`. Terragrunt reads them with `get_env()` (`ARM_TENANT_ID`, `DATABRICKS_ACCOUNT_ID`, `DATABRICKS_METASTORE_ID`, `TFSTATE_*`); placeholders only under `PLATFORM_OFFLINE=true`.
- Generate secrets with `random_password` / `ephemeral` resources and write them straight to Key Vault; consumers read via Key Vault references or CSI driver, not Terraform outputs.
- Outputs that carry credentials (e.g. `kube_config_raw`) must be `sensitive = true` and should not exist at all if a managed identity path is available.
- `*.auto.tfvars` holding real values stay out of git; commit `*.tfvars.example`.

## Network exposure defaults

- `public_network_access_enabled = false` on Key Vault, Storage, ACR, Databricks workspace, Log Analytics ingestion where the SKU supports it; expose through Private Endpoints + Private DNS.
- AKS: `private_cluster_enabled = true` (or API server VNet integration + `authorized_ip_ranges`), no public node IPs.
- Databricks: `no_public_ip = true` (Secure Cluster Connectivity) and VNet injection.
- NSGs deny inbound from `Internet` by default; never `source_address_prefix = "*"` on management ports.

## Identity

- Managed identities and workload identity over service principals with secrets. See [../azure/identity.md](../azure/identity.md).
- RBAC assignments scoped to the narrowest resource; never `Owner` / `Contributor` at subscription scope from Terraform modules.
- Key Vault uses `rbac_authorization_enabled = true` (no access policies), `purge_protection_enabled = true`, soft delete >= 7 days.

## Data protection

- Storage: `min_tls_version = "TLS1_2"`, `shared_access_key_enabled = false`, `allow_nested_items_to_be_public = false`, `https_traffic_only_enabled = true`, infrastructure encryption on for data lakes.
- Enable diagnostic settings to the shared Log Analytics workspace for every resource that supports them.
- Customer-managed keys where policy requires (Databricks managed services/disks, storage) - flag missing CMK in prod as a finding.

## Scanning

- `checkov -d infra --framework terraform` (or `trivy config infra`) must pass in CI; suppressions use inline `#checkov:skip=CKV_AZURE_xxx: <reason>` with a justification, never blanket skips.
- `tflint --recursive` with the `azurerm` ruleset.

## Supply chain

- Pin providers with `~>` on minor and commit `.terraform.lock.hcl` for `infra/bootstrap` and every Terragrunt unit (multi-platform, `make lock`). CI inits with `-lockfile=readonly`.
- Terraform and Terragrunt binaries are pinned (`common.hcl` version constraints, CI env) and installed with checksum verification.
- Registry modules pinned to an exact version; prefer Azure Verified Modules (`Azure/avm-res-*`) over unvetted community modules.
