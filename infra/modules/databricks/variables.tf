variable "access_connector_id" {
  type        = string
  description = "Access connector used to reach the workspace default storage when its firewall is enabled."
  default     = null
}

variable "container_subnet_name" {
  type        = string
  description = "Name of the delegated container (private) subnet."
}

variable "container_subnet_nsg_association_id" {
  type        = string
  description = "NSG association ID of the container subnet."
}

variable "default_storage_firewall_enabled" {
  type        = bool
  description = "Enable the firewall on the workspace-managed DBFS storage account (requires access_connector_id)."
  default     = false

  validation {
    condition     = !var.default_storage_firewall_enabled || var.access_connector_id != null
    error_message = "access_connector_id is required when default_storage_firewall_enabled = true."
  }
}

variable "diagnostics" {
  type = object({
    enabled                    = bool
    log_analytics_workspace_id = optional(string)
  })
  description = "Send Databricks audit/diagnostic logs to Log Analytics."
  default     = { enabled = false }

  validation {
    condition     = !var.diagnostics.enabled || var.diagnostics.log_analytics_workspace_id != null
    error_message = "log_analytics_workspace_id is required when diagnostics are enabled."
  }
}

variable "host_subnet_name" {
  type        = string
  description = "Name of the delegated host (public) subnet."
}

variable "host_subnet_nsg_association_id" {
  type        = string
  description = "NSG association ID of the host subnet."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "managed_resource_group_name" {
  type        = string
  description = "Name of the Databricks-managed resource group (rg-<workspace>-managed). Changing it replaces the workspace."
}

variable "name" {
  type        = string
  description = "Workspace name (dbw-<workload>-<env>-<region>-<nn>)."
}

variable "private_endpoint" {
  type = object({
    enabled                       = bool
    subnet_id                     = optional(string)
    private_dns_zone_id           = optional(string)
    create_browser_authentication = optional(bool, false)
  })
  description = "Private Link: databricks_ui_api endpoint (front-end + back-end) and optionally the regional browser_authentication endpoint."
  default     = { enabled = false }

  validation {
    condition     = !var.private_endpoint.enabled || var.private_endpoint.subnet_id != null
    error_message = "subnet_id is required when the private endpoint is enabled."
  }
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Allow front-end access from the internet. When false, NSG rules switch to NoAzureDatabricksRules and the private endpoint is required."
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

variable "virtual_network_id" {
  type        = string
  description = "VNet ID used for VNet injection."
}
