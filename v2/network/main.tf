# ---------------------------------------------------------------------------
# Shared networking (applied FIRST). Owns the VNet, the private-endpoint
# subnet, and the private DNS zones reused by both Foundry instances.
# The agent subnet is intentionally NOT created here - it belongs to the
# agent-services root so it stays reserved for that instance.
# ---------------------------------------------------------------------------

locals {
  location = "eastus2"

  dns_zone_names = {
    cognitiveservices = "privatelink.cognitiveservices.azure.com"
    ai_services       = "privatelink.services.ai.azure.com"
    openai            = "privatelink.openai.azure.com"
  }
}

resource "azurerm_resource_group" "network" {
  name     = var.network_resource_group_name
  location = local.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = local.location
  resource_group_name = azurerm_resource_group.network.name
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "pe" {
  name                 = var.pe_subnet_name
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.pe_subnet_prefix]
}

resource "azurerm_private_dns_zone" "zones" {
  for_each            = local.dns_zone_names
  name                = each.value
  resource_group_name = azurerm_resource_group.network.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each              = local.dns_zone_names
  name                  = "${each.key}-link"
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.zones[each.key].name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
}
