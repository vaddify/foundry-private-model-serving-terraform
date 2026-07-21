# ---------------------------------------------------------------------------
# Look up shared network resources created by the `network` root.
# The agent subnet is NOT looked up - this root creates it (reserved for agents).
# ---------------------------------------------------------------------------

locals {
  location = "eastus2"

  dns_zone_names = {
    cognitiveservices = "privatelink.cognitiveservices.azure.com"
    ai_services       = "privatelink.services.ai.azure.com"
    openai            = "privatelink.openai.azure.com"
  }
}

data "azurerm_subnet" "pe" {
  name                 = var.pe_subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.network_resource_group_name
}

data "azurerm_private_dns_zone" "zones" {
  for_each            = local.dns_zone_names
  name                = each.value
  resource_group_name = var.network_resource_group_name
}
