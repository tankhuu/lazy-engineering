variable "diagnostics" {
  type = object({
    enabled                    = bool
    log_analytics_workspace_id = optional(string)
  })
  description = "Send registry logs and metrics to Log Analytics."
  default     = { enabled = false }

  validation {
    condition     = !var.diagnostics.enabled || var.diagnostics.log_analytics_workspace_id != null
    error_message = "log_analytics_workspace_id is required when diagnostics are enabled."
  }
}

variable "georeplication_locations" {
  type        = list(string)
  description = "Additional regions to replicate the registry to."
  default     = []
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "name" {
  type        = string
  description = "Registry name (cr<workload><env><region><nn>, 5-50 alphanumerics, globally unique)."

  validation {
    condition     = can(regex("^[a-zA-Z0-9]{5,50}$", var.name))
    error_message = "ACR name must be 5-50 alphanumeric characters."
  }
}

variable "private_endpoint" {
  type = object({
    enabled             = bool
    subnet_id           = optional(string)
    private_dns_zone_id = optional(string)
  })
  description = "Private endpoint (subresource registry), registered in privatelink.azurecr.io."
  default     = { enabled = false }

  validation {
    condition     = !var.private_endpoint.enabled || var.private_endpoint.subnet_id != null
    error_message = "subnet_id is required when the private endpoint is enabled."
  }
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Allow pulls/pushes over the public endpoint."
  default     = false
}

variable "quarantine_policy_enabled" {
  type        = bool
  description = "Quarantine pushed images until a scanner releases them."
  default     = false
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default     = {}
}

variable "untagged_retention_days" {
  type        = number
  description = "Days to keep untagged manifests before purge."
  default     = 7
}

variable "zone_redundancy_enabled" {
  type        = bool
  description = "Zone-redundant registry (region must support zones)."
  default     = true
}
