# ---------------------------------------------------------------------------
# STEP 2 - Create a Project (in East US 2 by default via var.location)
# The project is a child of the Foundry account and inherits its region.
# ---------------------------------------------------------------------------

resource "azapi_resource" "project" {
  depends_on = [
    azapi_resource.foundry,
    azurerm_private_endpoint.pe_aifoundry,
  ]

  type                      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  name                      = var.project_name
  parent_id                 = azapi_resource.foundry.id
  location                  = azurerm_resource_group.this.location
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

# ---------------------------------------------------------------------------
# Optional capability host (basic agent, platform-managed - no BYO resources).
# Only created when var.enable_agent_capability_host = true. Not needed to
# serve/call model deployments; required to run Foundry Agents.
# ---------------------------------------------------------------------------
resource "azapi_resource" "project_capability_host" {
  count = var.enable_agent_capability_host ? 1 : 0

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
