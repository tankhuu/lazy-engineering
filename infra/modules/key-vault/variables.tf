variable "allowed_ip_ranges" {
  type        = list(string)
  description = "Public IP ranges allowed through the firewall (only effective when public access is enabled)."
  default     = []
}

variable "diagnostics" {
  type = object({
    enabled                    = bool
    log_analytics_workspace_id = optional(string)
  })
  description = "Send audit logs and metrics to Log Analytics."
  default     = { enabled = false }

  validation {
    condition     = !var.diagnostics.enabled || var.diagnostics.log_analytics_workspace_id != null
    error_message = "log_analytics_workspace_id is required when diagnostics are enabled."
  }
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "name" {
  type        = string
  description = "Key Vault name (kv-<workload>-<env>-<region>, 3-24 chars, globally unique)."

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.name))
    error_message = "Key Vault name must be 3-24 alphanumerics/hyphens, start with a letter and not end with a hyphen."
  }
}

variable "private_endpoint" {
  type = object({
    enabled             = bool
    subnet_id           = optional(string)
    private_dns_zone_id = optional(string)
  })
  description = "Private endpoint (subresource vault) in the given subnet, registered in privatelink.vaultcore.azure.net."
  default     = { enabled = false }

  validation {
    condition     = !var.private_endpoint.enabled || var.private_endpoint.subnet_id != null
    error_message = "subnet_id is required when the private endpoint is enabled."
  }
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Allow access over the public endpoint (firewall still applies)."
  default     = false
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name."
}

variable "role_assignments" {
  type = map(object({
    role_definition_name = string
    principal_id         = string
    principal_type       = optional(string, "Group")
  }))
  description = "Data-plane RBAC on the vault keyed by a stable name, e.g. { platform_admins = { role_definition_name = \"Key Vault Administrator\", principal_id = \"...\" } }."
  default     = {}
}

variable "sku_name" {
  type        = string
  description = "standard or premium (HSM-backed keys)."
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.sku_name)
    error_message = "sku_name must be standard or premium."
  }
}

variable "soft_delete_retention_days" {
  type        = number
  description = "Soft delete retention (7-90 days)."
  default     = 90

  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "soft_delete_retention_days must be between 7 and 90."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default     = {}
}

variable "tenant_id" {
  type        = string
  description = "Entra ID tenant ID."
}
