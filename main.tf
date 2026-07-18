# ---------------------------------------------------------------------------
# STEP 1 - Deploy Microsoft Foundry
# Resource group + Microsoft Foundry (AI Services) account with project
# management enabled. This is the top-level container for projects & models.
# ---------------------------------------------------------------------------

locals {
  # Region is fixed: everything is always deployed to East US 2.
  location = "eastus2"
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = local.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Virtual network + subnets (/26).
# - Agent subnet: delegated to Microsoft.App/environments (VNet injection).
# - PE subnet:    hosts the private endpoint for the Foundry account.
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = local.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.virtual_network_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "subnet_agent" {
  name                 = "snet-agent"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.agent_subnet_address_prefix]

  delegation {
    name = "Microsoft.App/environments"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "subnet_pe" {
  name                 = "snet-pe"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.private_endpoint_subnet_address_prefix]
}

# ---------------------------------------------------------------------------
# Microsoft Foundry (AI Services) account.
# Public network access DISABLED + VNet injection for agents.
# Reachable only from inside the VNet (VM / VPN / ExpressRoute).
# ---------------------------------------------------------------------------
resource "azapi_resource" "foundry" {
  depends_on = [
    azurerm_subnet.subnet_agent,
    azapi_resource_action.purge_ai_foundry,
  ]

  type                      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  name                      = var.foundry_account_name
  parent_id                 = azurerm_resource_group.this.id
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
      # Entra ID (token) auth only; API-key auth disabled.
      # Matches the platform-enforced state and avoids perpetual drift.
      disableLocalAuth = true
      # Enables the project-based Microsoft Foundry experience.
      allowProjectManagement = true
      # Custom subdomain is required for token-based (Entra ID) auth + private DNS.
      customSubDomainName = var.foundry_account_name

      # Disable public access; allow trusted Azure services.
      publicNetworkAccess = "Disabled"
      networkAcls = {
        defaultAction = "Allow"
      }

      # VNet injection for Agents (agent subnet must be delegated).
      networkInjections = [
        {
          scenario                   = "agent"
          subnetArmId                = azurerm_subnet.subnet_agent.id
          useMicrosoftManagedNetwork = false
        }
      ]
    }
  }

  response_export_values = ["properties.endpoint"]
}
