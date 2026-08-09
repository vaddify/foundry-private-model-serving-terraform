locals {
  # Foundry project data-plane endpoint, derived from the account's custom subdomain.
  project_endpoint = format(
    "https://%s.services.ai.azure.com/api/projects/%s",
    data.azapi_resource.account.output.properties.customSubDomainName,
    var.project_name
  )

  # ---------------------------------------------------------------------------
  # Connection properties. `properties` is a discriminated union on authType, so
  # the credentials block differs per variant. Anything not matching the active
  # authType must be absent, not null - hence the merge-of-conditionals shape.
  # ---------------------------------------------------------------------------
  connection_credentials = {
    None       = {}
    CustomKeys = { credentials = { keys = var.mcp_custom_keys } }
    OAuth2 = {
      credentials = {
        clientId     = var.oauth2_client_id
        clientSecret = var.oauth2_client_secret
      }
    }
  }

  connection_properties = merge(
    {
      category      = var.mcp_connection_category
      target        = var.mcp_server_url
      authType      = var.mcp_auth_type
      isSharedToAll = var.is_shared_to_all
      metadata      = var.mcp_connection_metadata
    },
    local.connection_credentials[var.mcp_auth_type]
  )
}

# ---------------------------------------------------------------------------
# Existing landing zone. Looked up, never created. A failure here means bad
# inputs - it says nothing about the hypothesis.
# ---------------------------------------------------------------------------

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azapi_resource" "account" {
  type      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  name      = var.account_name
  parent_id = data.azurerm_resource_group.this.id

  response_export_values = [
    "kind",
    "properties.customSubDomainName",
    "properties.endpoint",
    "properties.publicNetworkAccess",
  ]
}

data "azapi_resource" "project" {
  type      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  name      = var.project_name
  parent_id = data.azapi_resource.account.id

  response_export_values = ["properties"]
}

# ---------------------------------------------------------------------------
# THE ONLY RESOURCE THIS MODULE CREATES.
#
# If this applies cleanly, an MCP tool connection exists on a project with no
# agent and no Agent Service configuration. If the RP rejects it, the error body
# distinguishes between a bad category value, a too-old API version, and a
# genuine Agent Service dependency.
#
# schema_validation_enabled is off because the published schema has no MCP
# category and does not document MCP metadata keys. We want the RP's opinion,
# not the client library's.
# ---------------------------------------------------------------------------
resource "azapi_resource" "mcp_connection" {
  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@${var.connection_api_version}"
  name                      = var.connection_name
  parent_id                 = data.azapi_resource.project.id
  schema_validation_enabled = false

  body = {
    properties = local.connection_properties
  }

  response_export_values = ["*"]
}

# ---------------------------------------------------------------------------
# No role assignments, no agent, no models, no networking. Everything else
# already exists in the Lean & Private landing zone. Keeping the blast radius
# to a single resource is what makes the result interpretable.
# ---------------------------------------------------------------------------
