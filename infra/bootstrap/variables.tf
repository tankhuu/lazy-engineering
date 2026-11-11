variable "allow_public_access" {
  type        = bool
  description = "Keep the public endpoint enabled (still firewalled) so GitHub-hosted runners can reach state. Set false with self-hosted runners in the VNet."
  default     = true
}

variable "allowed_ip_ranges" {
  type        = list(string)
  description = "Public IPs/CIDRs allowed through the storage firewall (operator egress, NAT of self-hosted runners)."
  default     = []
}

variable "container_name" {
  type        = string
  description = "Blob container that holds state files (one key per env)."
  default     = "tfstate"
}

variable "location" {
  type        = string
  description = "Azure region."
  default     = "westeurope"
}

variable "replication_type" {
  type        = string
  description = "Storage replication. ZRS minimum; GZRS for cross-region resilience."
  default     = "ZRS"

  validation {
    condition     = contains(["ZRS", "GRS", "GZRS", "RAGZRS"], var.replication_type)
    error_message = "Use ZRS, GRS, GZRS or RAGZRS for state storage."
  }
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for state storage (rg-tfstate-<org>-<region>)."
}

variable "soft_delete_retention_days" {
  type        = number
  description = "Blob and container soft-delete retention."
  default     = 30
}

variable "state_reader_principals" {
  type = map(object({
    principal_id   = string
    principal_type = optional(string, "Group")
  }))
  description = "Principals granted Storage Blob Data Reader (e.g. PR plan identity)."
  default     = {}
}

variable "state_writer_principals" {
  type = map(object({
    principal_id   = string
    principal_type = optional(string, "ServicePrincipal")
  }))
  description = "Principals granted Storage Blob Data Contributor (e.g. CI apply identity, platform admins)."
  default     = {}
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique storage account name (st<org>tfstate<region>, 3-24 lowercase alnum)."

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be 3-24 lowercase letters or digits."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags for all resources."
  default = {
    managed_by = "terraform"
    repo       = "lazy-engineering"
    workload   = "tfstate"
  }
}
