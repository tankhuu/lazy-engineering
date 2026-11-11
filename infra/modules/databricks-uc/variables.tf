variable "access_connector_name" {
  type        = string
  description = "Databricks access connector name (dbac-<workload>-<env>-<region>-<nn>)."
}

variable "catalogs" {
  type = map(object({
    comment = optional(string)
    grants  = optional(map(list(string)), {})
  }))
  description = "Catalogs keyed by name; grants map account-group name => privileges, e.g. { data_engineers = [\"USE_CATALOG\", \"CREATE_SCHEMA\"] }."
  default     = {}
}

variable "cluster_policy" {
  type = object({
    allowed_node_types          = optional(list(string), ["Standard_D4ds_v5", "Standard_D8ds_v5", "Standard_E8ds_v5"])
    max_autotermination_minutes = optional(number, 60)
    spark_version_regex         = optional(string, "1[5-9]\\.[0-9]+\\.x-scala.*")
  })
  description = "Guardrails for the jobs cluster policy."
  default     = {}
}

variable "environment" {
  type        = string
  description = "Environment name used in UC object names and fixed cluster tags."

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test or prod."
  }
}

variable "location" {
  type        = string
  description = "Azure region (also the metastore region)."
}

variable "metastore" {
  type = object({
    create = bool
    id     = optional(string)
    name   = optional(string)
    owner  = optional(string)
  })
  description = "Create a regional metastore (once per account+region) or attach to an existing one by ID."

  validation {
    condition     = var.metastore.create ? var.metastore.name != null : var.metastore.id != null
    error_message = "Set metastore.name when create = true, otherwise metastore.id."
  }
}

variable "private_endpoint" {
  type = object({
    enabled              = bool
    subnet_id            = optional(string)
    private_dns_zone_ids = optional(map(string), {})
  })
  description = "Private endpoints for the UC storage account (blob + dfs); private_dns_zone_ids keyed by subresource."
  default     = { enabled = false }

  validation {
    condition     = !var.private_endpoint.enabled || var.private_endpoint.subnet_id != null
    error_message = "subnet_id is required when private endpoints are enabled."
  }
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for the storage account and access connector."
}

variable "storage_account_name" {
  type        = string
  description = "ADLS Gen2 account for UC managed storage (st<workload><env><region>uc, 3-24 lowercase alphanumerics)."

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be 3-24 lowercase alphanumerics."
  }
}

variable "storage_replication_type" {
  type        = string
  description = "Replication for the UC storage account."
  default     = "ZRS"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to Azure resources; cost_center also becomes a fixed cluster tag."
  default     = {}
}

variable "workspace_id" {
  type        = string
  description = "Numeric Databricks workspace ID (module.databricks.workspace_id)."
}
