resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "id-${var.name}-control-plane"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "control_plane_subnet" {
  scope                = var.nodes_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "control_plane_route_table" {
  count = var.route_table.manage_role ? 1 : 0

  scope                = var.route_table.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "control_plane_private_dns" {
  count = var.private_cluster_enabled && var.private_dns_zone_manage_role ? 1 : 0

  scope                = var.private_dns_zone_id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "kubelet_acr_pull" {
  count = var.acr.attach ? 1 : 0

  scope                            = var.acr.id
  role_definition_name             = "AcrPull"
  principal_id                     = one(azurerm_kubernetes_cluster.this.kubelet_identity[*].object_id)
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_user_assigned_identity" "workload" {
  for_each = var.workload_identities

  name                = "id-${var.name}-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "workload" {
  for_each = var.workload_identities

  name                      = "fic-${var.name}-${each.key}"
  user_assigned_identity_id = azurerm_user_assigned_identity.workload[each.key].id
  issuer                    = azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject                   = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
  audience                  = ["api://AzureADTokenExchange"]
}
