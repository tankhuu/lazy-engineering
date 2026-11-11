locals {
  nsg_subnets      = { for k, v in var.subnets : k => v if v.create_nsg }
  firewall_subnets = var.egress_next_hop_ip == null ? {} : { for k, v in var.subnets : k => v if v.route_via_firewall }
  nat_subnets      = var.nat_gateway.enabled ? { for k, v in var.subnets : k => v if v.nat_gateway } : {}
}

resource "azurerm_virtual_network" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  dns_servers         = var.dns_servers
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                              = each.key
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = each.value.address_prefixes
  private_endpoint_network_policies = each.value.private_endpoint_network_policies
  default_outbound_access_enabled   = false

  dynamic "service_endpoint" {
    for_each = toset(each.value.service_endpoints)

    content {
      service = service_endpoint.value
    }
  }

  dynamic "delegation" {
    for_each = each.value.delegation == null ? [] : [each.value.delegation]

    content {
      name = delegation.value.name

      service_delegation {
        name    = delegation.value.service_name
        actions = delegation.value.actions
      }
    }
  }
}

resource "azurerm_network_security_group" "this" {
  for_each = local.nsg_subnets

  name                = "nsg-${var.name}-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "deny_internet_inbound" {
  for_each = local.nsg_subnets

  name                        = "deny-internet-inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this[each.key].name
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = local.nsg_subnets

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

resource "azurerm_route_table" "this" {
  count = var.egress_next_hop_ip == null ? 0 : 1

  name                          = "rt-${var.name}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  bgp_route_propagation_enabled = false
  tags                          = var.tags

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.egress_next_hop_ip
  }
}

resource "azurerm_subnet_route_table_association" "this" {
  for_each = local.firewall_subnets

  subnet_id      = azurerm_subnet.this[each.key].id
  route_table_id = azurerm_route_table.this[0].id
}

resource "azurerm_public_ip" "nat" {
  count = var.nat_gateway.enabled ? 1 : 0

  name                = "pip-ng-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.nat_gateway.zones
  tags                = var.tags
}

resource "azurerm_nat_gateway" "this" {
  count = var.nat_gateway.enabled ? 1 : 0

  name                    = "ng-${var.name}"
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = var.nat_gateway.idle_min
  zones                   = var.nat_gateway.zones
  tags                    = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  count = var.nat_gateway.enabled ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.this[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "this" {
  for_each = local.nat_subnets

  subnet_id      = azurerm_subnet.this[each.key].id
  nat_gateway_id = azurerm_nat_gateway.this[0].id
}

resource "azurerm_virtual_network_peering" "to_hub" {
  count = var.hub_vnet_id == null ? 0 : 1

  name                         = "peer-${var.name}-to-hub"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.this.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = var.use_hub_gateways
}

resource "azurerm_private_dns_zone" "this" {
  for_each = var.private_dns_zones

  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = var.private_dns_zones

  name                 = "link-${var.name}"
  private_dns_zone_id  = azurerm_private_dns_zone.this[each.key].id
  virtual_network_id   = azurerm_virtual_network.this.id
  registration_enabled = false
  tags                 = var.tags
}
