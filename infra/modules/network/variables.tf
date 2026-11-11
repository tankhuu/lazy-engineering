variable "address_space" {
  type        = list(string)
  description = "Address space of the spoke virtual network."

  validation {
    condition     = length(var.address_space) > 0 && alltrue([for c in var.address_space : can(cidrhost(c, 0))])
    error_message = "address_space must contain at least one valid CIDR."
  }
}

variable "dns_servers" {
  type        = list(string)
  description = "Custom DNS servers (e.g. hub DNS Private Resolver inbound IP). Empty uses Azure DNS."
  default     = []
}

variable "egress_next_hop_ip" {
  type        = string
  description = "Private IP of the hub firewall/NVA. When set, a route table sends 0.0.0.0/0 there for subnets with route_via_firewall = true."
  default     = null
}

variable "hub_vnet_id" {
  type        = string
  description = "Resource ID of the hub VNet to peer with (spoke side only). Null disables peering."
  default     = null
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "name" {
  type        = string
  description = "Virtual network name (vnet-<workload>-<env>-<region>-<nn>)."
}

variable "nat_gateway" {
  type = object({
    enabled  = bool
    zones    = optional(list(string), ["1"])
    idle_min = optional(number, 4)
  })
  description = "Create a NAT Gateway for subnets with nat_gateway = true (used when there is no hub firewall)."
  default     = { enabled = false }
}

variable "private_dns_zones" {
  type        = set(string)
  description = "Private DNS zones to create and link locally. Leave empty when zones live in the hub."
  default     = []
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for all network resources."
}

variable "subnets" {
  type = map(object({
    address_prefixes                  = list(string)
    service_endpoints                 = optional(list(string), [])
    private_endpoint_network_policies = optional(string, "Disabled")
    create_nsg                        = optional(bool, true)
    route_via_firewall                = optional(bool, true)
    nat_gateway                       = optional(bool, false)
    delegation = optional(object({
      name         = string
      service_name = string
      actions      = list(string)
    }))
  }))
  description = "Subnets keyed by subnet name."

  validation {
    condition = alltrue(flatten([
      for s in values(var.subnets) : [for p in s.address_prefixes : can(cidrhost(p, 0))]
    ]))
    error_message = "Every subnet address prefix must be a valid CIDR."
  }

  validation {
    condition = alltrue([
      for s in values(var.subnets) : contains(["Disabled", "Enabled", "NetworkSecurityGroupEnabled", "RouteTableEnabled"], s.private_endpoint_network_policies)
    ])
    error_message = "private_endpoint_network_policies must be Disabled, Enabled, NetworkSecurityGroupEnabled or RouteTableEnabled."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default     = {}
}

variable "use_hub_gateways" {
  type        = bool
  description = "Use the hub's VPN/ExpressRoute gateway through peering."
  default     = false
}
