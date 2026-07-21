variable "subscription_id" {
  type        = string
  description = "Azure subscription ID."
}

variable "network_resource_group_name" {
  type        = string
  description = "Resource group for the shared networking resources."
  default     = "rg-foundry-network"
}

variable "vnet_name" {
  type        = string
  description = "Shared virtual network name."
  default     = "vnet-foundry-eus2"
}

variable "vnet_address_space" {
  type        = string
  description = "CIDR for the shared VNet. Must contain the PE subnet (and later the agent subnet)."
  default     = "192.168.0.0/24"
}

variable "pe_subnet_name" {
  type        = string
  description = "Name of the shared private-endpoint subnet."
  default     = "snet-pe"
}

variable "pe_subnet_prefix" {
  type        = string
  description = "Private-endpoint subnet (/26)."
  default     = "192.168.0.64/26"
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
