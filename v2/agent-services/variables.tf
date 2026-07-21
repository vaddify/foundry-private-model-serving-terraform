variable "subscription_id" {
  type        = string
  description = "Azure subscription ID."
}

variable "agent_resource_group_name" {
  type        = string
  description = "Resource group for the agent-services Foundry instance."
  default     = "rg-foundry-agent"
}

variable "foundry_account_name" {
  type        = string
  description = "Agent-services Foundry account name. Globally unique + DNS-safe."
  default     = "foundry-agent-eus2"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$", var.foundry_account_name))
    error_message = "Must be lowercase alphanumeric/hyphens, 3-64 chars, start/end alphanumeric."
  }
}

variable "project_name" {
  type        = string
  description = "Foundry project name."
  default     = "proj-agent-eus2"
}

variable "project_display_name" {
  type        = string
  description = "Project display name."
  default     = "Agent Services - East US 2"
}

variable "enable_capability_host" {
  type        = bool
  description = "Create the basic-agent capability host on the project."
  default     = true
}

# --- References to the shared network root (apply that first) ---
variable "network_resource_group_name" {
  type        = string
  description = "Resource group of the shared network."
  default     = "rg-foundry-network"
}

variable "vnet_name" {
  type        = string
  description = "Shared VNet name (agent subnet is created inside it)."
  default     = "vnet-foundry-eus2"
}

variable "pe_subnet_name" {
  type        = string
  description = "Shared private-endpoint subnet name."
  default     = "snet-pe"
}

variable "agent_subnet_name" {
  type        = string
  description = "Name of the agent subnet to create in the shared VNet."
  default     = "snet-agent"
}

variable "agent_subnet_prefix" {
  type        = string
  description = "Agent subnet (/26), delegated to Microsoft.App/environments. RFC1918 Class B or C."
  default     = "192.168.0.0/26"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default = {
    project     = "model-serving"
    environment = "dev"
    managed_by  = "terraform"
    workload    = "agents"
  }
}
