# ---------------------------------------------------------------------------
# Model-serving Foundry instance: LEAN.
# - No agent subnet, no networkInjections, no capability host, no purge helper.
# - Public access disabled; reachable via the shared private endpoint + DNS.
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "serve" {
  name     = var.serve_resource_group_name
  location = local.location
  tags     = var.tags
}

resource "azapi_resource" "foundry" {
  type                      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  name                      = var.foundry_account_name
  parent_id                 = azurerm_resource_group.serve.id
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
      # Entra-ID auth only (no API keys); matches common policy + avoids drift.
      disableLocalAuth       = true
      allowProjectManagement = true
      customSubDomainName    = var.foundry_account_name

      publicNetworkAccess = "Disabled"
      networkAcls = {
        defaultAction = "Allow"
      }
      # NOTE: no networkInjections - agent VNet injection is intentionally omitted.
    }
  }

  response_export_values = ["properties.endpoint"]
}

resource "azurerm_private_endpoint" "pe_foundry" {
  depends_on = [azapi_resource.foundry]

  name                = "${var.foundry_account_name}-private-endpoint"
  location            = local.location
  resource_group_name = azurerm_resource_group.serve.name
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

resource "azapi_resource" "project" {
  depends_on = [
    azapi_resource.foundry,
    azurerm_private_endpoint.pe_foundry,
  ]

  type                      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  name                      = var.project_name
  parent_id                 = azapi_resource.foundry.id
  location                  = local.location
  tags                      = var.tags
  schema_validation_enabled = false

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
      displayName = var.project_display_name
      description = "Model serving project managed by Terraform."
    }
  }
}
