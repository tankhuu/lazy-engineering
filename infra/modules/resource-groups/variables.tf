variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_groups" {
  type        = map(string)
  description = "Resource group names keyed by purpose (network, shared, aks, databricks)."

  validation {
    condition     = alltrue([for n in values(var.resource_groups) : can(regex("^rg-[a-z0-9-]{1,86}$", n))])
    error_message = "Resource group names must start with rg- and use lowercase letters, digits and hyphens."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource group."
  default     = {}
}
