# ---------------------------------------------------------------------------
# Foundry project + capability host (enables Foundry Agents).
# ---------------------------------------------------------------------------

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
      description = "Agent services project managed by Terraform."
    }
  }
}

resource "azapi_resource" "project_capability_host" {
  count = var.enable_capability_host ? 1 : 0

  depends_on = [azapi_resource.project]

  type                      = "Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview"
  name                      = "caphostproj"
  parent_id                 = azapi_resource.project.id
  schema_validation_enabled = false

  body = {
    properties = {
      capabilityHostKind = "Agents"
    }
  }
}
