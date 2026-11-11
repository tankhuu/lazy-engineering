output "control_plane_identity_principal_id" {
  description = "Principal ID of the control-plane user-assigned identity."
  value       = azurerm_user_assigned_identity.control_plane.principal_id
}

output "id" {
  description = "AKS cluster resource ID."
  value       = azurerm_kubernetes_cluster.this.id
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet identity (grant AcrPull / storage roles to this)."
  value       = one(azurerm_kubernetes_cluster.this.kubelet_identity[*].object_id)
}

output "name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.this.name
}

output "node_resource_group" {
  description = "Managed node resource group."
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity federation."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "private_fqdn" {
  description = "Private API server FQDN (null for public clusters)."
  value       = azurerm_kubernetes_cluster.this.private_fqdn
}

output "workload_identity_client_ids" {
  description = "Client IDs of workload identities keyed by app name (annotate service accounts with azure.workload.identity/client-id)."
  value       = { for k, v in azurerm_user_assigned_identity.workload : k => v.client_id }
}
