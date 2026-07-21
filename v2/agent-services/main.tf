# ---------------------------------------------------------------------------
# Agent-services Foundry instance.
# - Creates the single agent-delegated subnet in the shared VNet (reserved
#   exclusively for agents).
# - Account uses networkInjections (VNet injection) for the agent runtime.
# - Public access disabled; reachable via the shared private endpoint + DNS.
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "agent" {
  name     = var.agent_resource_group_name
  location = local.location
  tags     = var.tags
}

# Agent subnet lives in the shared VNet but is owned by this root.
resource "azurerm_subnet" "agent" {
  name                 = var.agent_subnet_name
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.vnet_name
  address_prefixes     = [var.agent_subnet_prefix]

  delegation {
    name = "Microsoft.App/environments"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azapi_resource" "foundry" {
  depends_on = [
    azurerm_subnet.agent,
    azapi_resource_action.purge_ai_foundry,
  ]

  type                      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  name                      = var.foundry_account_name
  parent_id                 = azurerm_resource_group.agent.id
  location                  = local.location
  tags                      = var.tags
  schema_validation_enabled = false

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "AIServices"
    sku = {
      name = "S0"
    }
    properties = {
      disableLocalAuth       = true
      allowProjectManagement = true
      customSubDomainName    = var.foundry_account_name

      publicNetworkAccess = "Disabled"
      networkAcls = {
        defaultAction = "Allow"
      }

      # VNet injection for the agent runtime.
      networkInjections = [
        {
          scenario                   = "agent"
          subnetArmId                = azurerm_subnet.agent.id
          useMicrosoftManagedNetwork = false
        }
      ]
    }
  }

  response_export_values = ["properties.endpoint"]
}

resource "azurerm_private_endpoint" "pe_foundry" {
  depends_on = [azapi_resource.foundry]

  name                = "${var.foundry_account_name}-private-endpoint"
  location            = local.location
  resource_group_name = azurerm_resource_group.agent.name
  subnet_id           = data.azurerm_subnet.pe.id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.foundry_account_name}-plsc"
    private_connection_resource_id = azapi_resource.foundry.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${var.foundry_account_name}-dns-config"
    private_dns_zone_ids = [for z in data.azurerm_private_dns_zone.zones : z.id]
  }
}
