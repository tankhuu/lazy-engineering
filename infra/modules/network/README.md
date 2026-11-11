# network

Spoke virtual network for the platform landing zone: subnets (with optional delegation), one NSG per subnet with an explicit Internet deny, optional route table to the hub firewall, optional NAT Gateway, optional hub peering (spoke side), and optional local private DNS zones.

```hcl
module "network" {
  source              = "../../modules/network"
  name                = "vnet-plat-dev-weu-01"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.platform.name
  address_space       = ["10.10.0.0/20"]
  subnets = {
    snet-aks-nodes = { address_prefixes = ["10.10.0.0/22"] }
    snet-pe        = { address_prefixes = ["10.10.4.0/26"], route_via_firewall = false }
  }
  tags = local.tags
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9, < 2.0 |
| azurerm | ~> 5.13 |

## Providers

| Name | Version |
| ---- | ------- |
| azurerm | 5.13.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway) | resource |
| [azurerm_nat_gateway_public_ip_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway_public_ip_association) | resource |
| [azurerm_network_security_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_network_security_rule.deny_internet_inbound](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule) | resource |
| [azurerm_private_dns_zone.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone_virtual_network_link.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_public_ip.nat](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_route_table.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table) | resource |
| [azurerm_subnet.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet_nat_gateway_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_nat_gateway_association) | resource |
| [azurerm_subnet_network_security_group_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_subnet_route_table_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_route_table_association) | resource |
| [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azurerm_virtual_network_peering.to_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| address\_space | Address space of the spoke virtual network. | `list(string)` | n/a | yes |
| location | Azure region. | `string` | n/a | yes |
| name | Virtual network name (vnet-<workload>-<env>-<region>-<nn>). | `string` | n/a | yes |
| resource\_group\_name | Resource group for all network resources. | `string` | n/a | yes |
| subnets | Subnets keyed by subnet name. | ```map(object({ address_prefixes = list(string) service_endpoints = optional(list(string), []) private_endpoint_network_policies = optional(string, "Disabled") create_nsg = optional(bool, true) route_via_firewall = optional(bool, true) nat_gateway = optional(bool, false) delegation = optional(object({ name = string service_name = string actions = list(string) })) }))``` | n/a | yes |
| dns\_servers | Custom DNS servers (e.g. hub DNS Private Resolver inbound IP). Empty uses Azure DNS. | `list(string)` | `[]` | no |
| egress\_next\_hop\_ip | Private IP of the hub firewall/NVA. When set, a route table sends 0.0.0.0/0 there for subnets with route\_via\_firewall = true. | `string` | `null` | no |
| hub\_vnet\_id | Resource ID of the hub VNet to peer with (spoke side only). Null disables peering. | `string` | `null` | no |
| nat\_gateway | Create a NAT Gateway for subnets with nat\_gateway = true (used when there is no hub firewall). | ```object({ enabled = bool zones = optional(list(string), ["1"]) idle_min = optional(number, 4) })``` | ```{ "enabled": false }``` | no |
| private\_dns\_zones | Private DNS zones to create and link locally. Leave empty when zones live in the hub. | `set(string)` | `[]` | no |
| tags | Tags applied to every resource. | `map(string)` | `{}` | no |
| use\_hub\_gateways | Use the hub's VPN/ExpressRoute gateway through peering. | `bool` | `false` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| id | Virtual network resource ID. |
| name | Virtual network name. |
| nat\_gateway\_id | NAT Gateway ID, or null when disabled. |
| nsg\_association\_ids | Subnet-NSG association IDs keyed by subnet name (required by Databricks VNet injection). |
| nsg\_ids | NSG IDs keyed by subnet name. |
| private\_dns\_zone\_ids | Locally created private DNS zone IDs keyed by zone name. |
| route\_table\_id | Route table ID, or null when no egress firewall is configured. |
| subnet\_ids | Subnet IDs keyed by subnet name. |
<!-- END_TF_DOCS -->
