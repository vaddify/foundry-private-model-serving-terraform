variable "subscription_id" {
  type        = string
  description = "Azure subscription ID."
}

variable "serve_resource_group_name" {
  type        = string
  description = "Resource group for the model-serving Foundry instance."
  default     = "rg-foundry-serve"
}

variable "foundry_account_name" {
  type        = string
  description = "Model-serving Foundry account name. Globally unique + DNS-safe (used as custom subdomain)."
  default     = "foundry-serve-eus2"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$", var.foundry_account_name))
    error_message = "Must be lowercase alphanumeric/hyphens, 3-64 chars, start/end alphanumeric."
  }
}

variable "project_name" {
  type        = string
  description = "Foundry project name."
  default     = "proj-serve-eus2"
}

variable "project_display_name" {
  type        = string
  description = "Project display name."
  default     = "Model Serving - East US 2"
}

# --- References to the shared network root (apply that first) ---
variable "network_resource_group_name" {
  type        = string
  description = "Resource group of the shared network (from the network root)."
  default     = "rg-foundry-network"
}

variable "vnet_name" {
  type        = string
  description = "Shared VNet name."
  default     = "vnet-foundry-eus2"
}

variable "pe_subnet_name" {
  type        = string
  description = "Shared private-endpoint subnet name."
  default     = "snet-pe"
}

# --- Model selection ---
variable "model_name" {
  type        = string
  description = "Catalog key of the model to deploy. See local.model_catalog in models.tf."
  default     = "deepseek-v3"
}

variable "model_format" {
  type        = string
  default     = null
  description = "Override model format (null = catalog value)."
}

variable "model_version" {
  type        = string
  default     = null
  description = "Override model version (null = catalog value)."
}

variable "sku_name" {
  type        = string
  default     = null
  description = "Override deployment SKU (null = catalog value)."
}

variable "sku_capacity" {
  type        = number
  default     = null
  description = "Override deployment capacity (null = catalog value)."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default = {
    project     = "model-serving"
    environment = "dev"
    managed_by  = "terraform"
    workload    = "serving"
  }
}
