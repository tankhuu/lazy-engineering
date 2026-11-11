variable "acr" {
  type = object({
    attach = bool
    id     = optional(string)
  })
  description = "Grant the kubelet identity AcrPull on this registry."
  default     = { attach = false }

  validation {
    condition     = !var.acr.attach || var.acr.id != null
    error_message = "acr.id is required when acr.attach = true."
  }
}

variable "admin_group_object_ids" {
  type        = list(string)
  description = "Entra ID groups granted cluster-admin through Entra RBAC."
}

variable "automatic_upgrade_channel" {
  type        = string
  description = "AKS auto-upgrade channel."
  default     = "patch"

  validation {
    condition     = contains(["none", "patch", "stable", "rapid", "node-image"], var.automatic_upgrade_channel)
    error_message = "automatic_upgrade_channel must be none, patch, stable, rapid or node-image."
  }
}

variable "diagnostic_log_categories" {
  type        = list(string)
  description = "AKS resource log categories sent to Log Analytics."
  default     = ["kube-audit-admin", "guard", "kube-controller-manager", "cluster-autoscaler"]
}

variable "enable_azure_policy" {
  type        = bool
  description = "Enable the Azure Policy add-on (Gatekeeper)."
  default     = true
}

variable "enable_defender" {
  type        = bool
  description = "Enable Microsoft Defender for Containers sensor."
  default     = false
}

variable "enable_diagnostics" {
  type        = bool
  description = "Create the diagnostic setting for control-plane logs."
  default     = true
}

variable "enable_keda" {
  type        = bool
  description = "Enable the KEDA add-on."
  default     = false
}

variable "enable_vpa" {
  type        = bool
  description = "Enable the Vertical Pod Autoscaler add-on."
  default     = false
}

variable "host_encryption_enabled" {
  type        = bool
  description = "Encrypt node temp/cache disks at host (requires subscription feature EncryptionAtHost)."
  default     = false
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes minor version (e.g. \"1.33\"); patch upgrades come from the upgrade channel."

  validation {
    condition     = can(regex("^1\\.[0-9]{2}$", var.kubernetes_version))
    error_message = "kubernetes_version must be a minor version like 1.33."
  }
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics workspace ID for Container Insights, Defender and diagnostics."
}

variable "maintenance_window" {
  type = object({
    day_of_week    = optional(string, "Sunday")
    start_time     = optional(string, "02:00")
    utc_offset     = optional(string, "+00:00")
    duration_hours = optional(number, 4)
  })
  description = "Weekly window for control-plane and node OS upgrades."
  default     = {}
}

variable "name" {
  type        = string
  description = "Cluster name (aks-<workload>-<env>-<region>-<nn>)."
}

variable "node_auto_provisioning" {
  type        = bool
  description = "Enable Node Auto Provisioning (Karpenter-based). Keep false to manage pools explicitly with the cluster autoscaler."
  default     = false
}

variable "nodes_subnet_id" {
  type        = string
  description = "Subnet ID for node pools (Azure CNI Overlay: pods do not consume VNet IPs)."
}

variable "outbound_type" {
  type        = string
  description = "Egress type: userDefinedRouting (hub firewall), userAssignedNATGateway, or loadBalancer."
  default     = "userDefinedRouting"

  validation {
    condition     = contains(["userDefinedRouting", "userAssignedNATGateway", "loadBalancer"], var.outbound_type)
    error_message = "outbound_type must be userDefinedRouting, userAssignedNATGateway or loadBalancer."
  }
}

variable "pod_cidr" {
  type        = string
  description = "Overlay pod CIDR; must not overlap VNet, hub, or on-prem ranges."
  default     = "192.168.0.0/16"
}

variable "private_cluster_enabled" {
  type        = bool
  description = "Private API server. Changing this replaces the cluster."
  default     = true
}

variable "private_dns_zone_id" {
  type        = string
  description = "\"System\", \"None\", or the ID of a BYO privatelink.<region>.azmk8s.io zone."
  default     = "System"
}

variable "private_dns_zone_manage_role" {
  type        = bool
  description = "Grant the control-plane identity Private DNS Zone Contributor on a BYO private_dns_zone_id. A plain bool so count stays known when the zone ID is computed."
  default     = false

  validation {
    condition     = !var.private_dns_zone_manage_role || !contains(["System", "None"], var.private_dns_zone_id)
    error_message = "private_dns_zone_manage_role requires private_dns_zone_id to be a zone resource ID."
  }
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for the cluster and its identities."
}

variable "route_table" {
  type = object({
    manage_role = bool
    id          = optional(string)
  })
  description = "Grant the control-plane identity Network Contributor on the subnet route table (needed for userDefinedRouting)."
  default     = { manage_role = false }

  validation {
    condition     = !var.route_table.manage_role || var.route_table.id != null
    error_message = "route_table.id is required when manage_role = true."
  }
}

variable "service_cidr" {
  type        = string
  description = "Kubernetes service CIDR; dns_service_ip is the 10th address."
  default     = "172.16.0.0/16"

  validation {
    condition     = can(cidrhost(var.service_cidr, 10))
    error_message = "service_cidr must be a valid CIDR with at least 11 addresses."
  }
}

variable "sku_tier" {
  type        = string
  description = "Free, Standard (uptime SLA) or Premium (LTS)."
  default     = "Standard"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be Free, Standard or Premium."
  }
}

variable "system_pool" {
  type = object({
    vm_size   = optional(string, "Standard_D4ds_v5")
    min_count = optional(number, 3)
    max_count = optional(number, 5)
    max_pods  = optional(number, 110)
    zones     = optional(list(string), ["1", "2", "3"])
    os_sku    = optional(string, "AzureLinux")
  })
  description = "System node pool (critical add-ons only)."
  default     = {}
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default     = {}
}

variable "tenant_id" {
  type        = string
  description = "Entra ID tenant for cluster RBAC."
}

variable "user_pools" {
  type = map(object({
    vm_size      = string
    min_count    = number
    max_count    = number
    max_pods     = optional(number, 110)
    zones        = optional(list(string), ["1", "2", "3"])
    os_sku       = optional(string, "AzureLinux")
    os_disk_type = optional(string, "Ephemeral")
    max_surge    = optional(string, "33%")
    labels       = optional(map(string), {})
    taints       = optional(list(string), [])
  }))
  description = "User node pools keyed by pool name (<= 12 lowercase alphanumerics)."
  default     = {}

  validation {
    condition     = alltrue([for k in keys(var.user_pools) : can(regex("^[a-z][a-z0-9]{0,11}$", k))])
    error_message = "Node pool names must be 1-12 lowercase alphanumerics starting with a letter."
  }
}

variable "workload_identities" {
  type = map(object({
    namespace       = string
    service_account = string
  }))
  description = "User-assigned identities federated to Kubernetes service accounts, keyed by app name."
  default     = {}
}
