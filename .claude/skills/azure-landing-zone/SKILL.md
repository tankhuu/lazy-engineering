---
name: azure-landing-zone
description: Azure landing zone context for platform engineers - management group/subscription hierarchy, connectivity (hub-spoke, DNS, firewall), what this repo owns vs the platform/connectivity layers, policy guardrails, and how a workload spoke (AKS + Databricks) plugs in. Use when deciding where a resource belongs or designing a new environment/subscription.
metadata:
  origin: lazy-engineering
---

# Azure Landing Zone (ALZ) Context

## Layers and ownership

| Layer | Owns | Where |
|-------|------|-------|
| Management groups + policy | MG hierarchy, Azure Policy/initiatives, Defender plans | ALZ platform repo (`Azure/avm-ptn-alz` / `caf-enterprise-scale`) |
| Management | Central Log Analytics, Automation, Sentinel | platform repo |
| Connectivity | Hub VNet, Azure Firewall, DNS Private Resolver, Private DNS zones, ER/VPN | connectivity repo |
| Identity | Entra groups, PIM, break-glass | identity process |
| Landing zone (this repo) | Spoke VNet, AKS, Databricks, KV, ACR, workload LAW, UC storage | `infra/deployment/<env>` (Terragrunt units) |

This repo consumes connectivity outputs as values in `infra/deployment/<env>/env.hcl`: `hub_vnet_id`, `egress_next_hop_ip` (hub firewall private IP), `hub_private_dns_zone_ids` (map by subresource). `null` means a standalone spoke (NAT gateway egress, local private DNS zones).

## Subscription model

- One subscription per env per workload (`sub-platform-dev`, `sub-platform-prod`) under the `landingzones/corp` MG (private, no public endpoints) - matching the "corp" policy set (deny public IPs, deny public PaaS endpoints, enforce diagnostics, enforce tags).
- Sandbox subscription for apply-mode tests.

## Spoke onboarding checklist

1. Request CIDR from IPAM; record `address_space` / `subnet_cidrs` in `infra/deployment/<env>/env.hcl`.
2. Peering spoke <-> hub (spoke side here, hub side via connectivity repo or `azurerm.connectivity` alias with limited RBAC).
3. Route table `0.0.0.0/0 -> hub firewall`; firewall rules for AKS (`AzureKubernetesService` FQDN tag) and Databricks (control plane, artifact, metastore, event hub endpoints by region).
4. Link spoke VNet to hub Private DNS zones (or Private DNS Resolver forwarding).
5. Diagnostic settings to central LAW, plus workload LAW for AKS Container Insights if separated.
6. Policy exemptions: request explicitly with expiry; never disable policy from this repo.

## Guardrails expected from policy (do not fight them)

- Deny public IP on NIC, deny public network access on PaaS, require private endpoints.
- Require tags (`environment`, `owner`, `cost_center`).
- AKS: deny privileged containers, require Azure Policy add-on, allowed images from ACR.
- Allowed regions and SKUs.

When a plan fails with `RequestDisallowedByPolicy`, read the policy assignment name from the error, check `az policy assignment show`, and fix the Terraform to comply rather than requesting an exemption first.
