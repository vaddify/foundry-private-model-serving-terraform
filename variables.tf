variable "subscription_id" {
  type        = string
  description = "Azure subscription ID to deploy into."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group that holds the Foundry account and project."
  default     = "rg-foundry-eastus2"
}

variable "foundry_account_name" {
  type        = string
  description = "Name of the Microsoft Foundry (AI Services) account. Also used as the custom subdomain, so it must be globally unique and DNS-safe."
  default     = "foundry-demo-eus2"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$", var.foundry_account_name))
    error_message = "foundry_account_name must be lowercase alphanumeric/hyphens, 3-64 chars, and start/end alphanumeric."
  }
}

variable "project_name" {
  type        = string
  description = "Name of the Foundry project created under the account."
  default     = "proj-demo-eus2"
}

variable "project_display_name" {
  type        = string
  description = "Friendly display name for the project."
  default     = "Model Serving - East US 2"
}

# ---------------------------------------------------------------------------
# Networking (private access). Subnets are /26 as requested.
# The VNet must be large enough to hold both /26 subnets (>= /25).
# Agent subnet should use RFC1918 Class B (172.16/12) or Class C (192.168/16).
# ---------------------------------------------------------------------------
variable "vnet_name" {
  type        = string
  description = "Name of the virtual network."
  default     = "vnet-foundry-eus2"
}

variable "virtual_network_address_space" {
  type        = string
  description = "CIDR for the VNet. Must contain both /26 subnets."
  default     = "192.168.0.0/24"
}

variable "agent_subnet_address_prefix" {
  type        = string
  description = "Agent subnet (/26), delegated to Microsoft.App/environments for VNet injection."
  default     = "192.168.0.0/26"
}

variable "private_endpoint_subnet_address_prefix" {
  type        = string
  description = "Private endpoint subnet (/26)."
  default     = "192.168.0.64/26"
}

# ---------------------------------------------------------------------------
# Agents (optional). Off by default: this stack serves/calls model deployments.
# Set to true only when you build Foundry Agents on the project.
# ---------------------------------------------------------------------------
variable "enable_agent_capability_host" {
  type        = bool
  description = "When true, creates a basic-agent capability host on the project (platform-managed, no BYO resources)."
  default     = false
}

# ---------------------------------------------------------------------------
# Model selection. Pass the catalog key here, e.g.:
#   terraform apply -var 'model_name=claude-sonnet'
# This branch focuses on Anthropic models (Opus / Sonnet).
# ---------------------------------------------------------------------------
variable "model_name" {
  type        = string
  description = "Catalog key of the model to deploy. See local.model_catalog in models.tf for supported values."
  default     = "claude-opus"
}

# Optional overrides. Leave null to use the values from the catalog.
variable "model_format" {
  type        = string
  description = "Override the model publisher/format (e.g. DeepSeek, OpenAI, MoonshotAI). Null = use catalog value."
  default     = null
}

variable "model_version" {
  type        = string
  description = "Override the model version. Null = use catalog value."
  default     = null
}

variable "sku_name" {
  type        = string
  description = "Override the deployment SKU (e.g. GlobalStandard, Standard, DataZoneStandard). Null = use catalog value."
  default     = null
}

variable "sku_capacity" {
  type        = number
  description = "Override the deployment capacity (tokens-per-minute units). Null = use catalog value."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default = {
    project     = "model-serving"
    environment = "dev"
    managed_by  = "terraform"
  }
}
