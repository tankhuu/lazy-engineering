variable "daily_quota_gb" {
  type        = number
  description = "Daily ingestion cap in GB; -1 means unlimited."
  default     = -1
}

variable "internet_ingestion_enabled" {
  type        = bool
  description = "Allow ingestion over the public internet (set false when using AMPLS)."
  default     = true
}

variable "internet_query_enabled" {
  type        = bool
  description = "Allow queries over the public internet (set false when using AMPLS)."
  default     = true
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "name" {
  type        = string
  description = "Workspace name (log-<workload>-<env>-<region>-<nn>)."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name."
}

variable "retention_in_days" {
  type        = number
  description = "Interactive retention in days."
  default     = 30

  validation {
    condition     = var.retention_in_days >= 30 && var.retention_in_days <= 730
    error_message = "retention_in_days must be between 30 and 730."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default     = {}
}
