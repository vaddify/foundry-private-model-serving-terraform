# ---------------------------------------------------------------------------
# Existing Lean & Private landing zone. Nothing below is created - these are
# lookups only. If one fails, the problem is your inputs, not the hypothesis.
# ---------------------------------------------------------------------------

variable "subscription_id" {
  description = "Subscription containing the existing Foundry account."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group containing the existing Foundry (AIServices) account."
  type        = string
}

variable "account_name" {
  description = "Existing Foundry account name (Microsoft.CognitiveServices/accounts, kind = AIServices)."
  type        = string
}

variable "project_name" {
  description = "Existing Foundry project name on that account."
  type        = string
}

# ---------------------------------------------------------------------------
# The hypothesis under test: can an MCP tool connection be created on this
# project with no Agent Service agent present, and is it then consumable?
# ---------------------------------------------------------------------------

variable "connection_name" {
  description = "Name for the MCP connection. ARM pattern: ^[a-zA-Z0-9][a-zA-Z0-9_-]{2,32}$"
  type        = string
  default     = "mcp-validation-conn"

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]{2,32}$", var.connection_name))
    error_message = "connection_name must match ^[a-zA-Z0-9][a-zA-Z0-9_-]{2,32}$."
  }
}

variable "mcp_server_url" {
  description = <<-EOT
    Remote MCP server endpoint the connection points at.

    Pass 1 should use a PUBLIC server so private networking is not a confounding
    variable. GitHub's public MCP server is what Microsoft's own documentation
    uses for this scenario.

    Only once a public target succeeds is it meaningful to repoint this at the
    Kong MCP listener and find out whether a private target is reachable at all.
  EOT
  type        = string
  default     = "https://api.githubcopilot.com/mcp"
}

variable "mcp_connection_category" {
  description = <<-EOT
    PRIMARY EXPERIMENTAL VARIABLE.

    The ARM schema for Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01
    does NOT define an "MCP" category. The type is an enum that terminates in `| string`,
    so any value passes client-side schema validation - but the resource provider may
    still reject it.

    Values worth testing, in order:
      1. "CustomKeys"  - what key/header-authenticated connections normally use
      2. "GenericRest" - closest generic HTTP category in the published enum
      3. "MCP"         - undocumented at this API version; try it, the RP may accept it

    Record which values the RP accepts. That answer is the real output of this run.
  EOT
  type        = string
  default     = "CustomKeys"
}

variable "connection_api_version" {
  description = <<-EOT
    API version for the connection resource. 2025-06-01 is the version the Bicep schema
    resolves to. If the CLI (`azd ai connection create`) uses a newer preview version that
    understands MCP natively, set it here and re-test.
  EOT
  type        = string
  default     = "2025-06-01"
}

variable "mcp_auth_type" {
  description = <<-EOT
    Discriminator for the connection properties union. Valid values per the ARM schema:
    AAD, AccessKey, AccountKey, ApiKey, CustomKeys, ManagedIdentity, None, OAuth2, PAT,
    SAS, ServicePrincipal, UsernamePassword.

    This module implements None, CustomKeys and OAuth2 - the three the MCP docs describe.

    NOTE ON GOVERNANCE: OAuth2 preserves the calling user's identity at the target system.
    ManagedIdentity does NOT - it collapses every caller into the project's service
    principal, which defeats per-user ACL binding in Unity Catalog / SharePoint. It is
    deliberately not implemented here.
  EOT
  type        = string
  default     = "None"

  validation {
    condition     = contains(["None", "CustomKeys", "OAuth2"], var.mcp_auth_type)
    error_message = "mcp_auth_type must be one of: None, CustomKeys, OAuth2."
  }
}

variable "mcp_custom_keys" {
  description = "Header name/value pairs when mcp_auth_type = CustomKeys. Example: { Authorization = \"Bearer ...\" }"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "oauth2_client_id" {
  description = "OAuth2 client ID when mcp_auth_type = OAuth2."
  type        = string
  default     = null
}

variable "oauth2_client_secret" {
  description = "OAuth2 client secret when mcp_auth_type = OAuth2. Supply via TF_VAR_oauth2_client_secret, never in a .tfvars file committed to git."
  type        = string
  default     = null
  sensitive   = true
}

variable "mcp_connection_metadata" {
  description = <<-EOT
    Free-form metadata written to the connection. The MCP-specific keys Foundry tooling
    expects are not published in the ARM schema, so this is left open for you to probe.
    Inspect a CLI-created connection to discover them:
      az rest --method GET --url "<connection resource id>?api-version=2025-06-01"
  EOT
  type        = map(string)
  default     = {}
}

variable "is_shared_to_all" {
  description = "Whether the connection is visible to all project members. Flip to false to test whether visibility scoping changes the outcome."
  type        = bool
  default     = true
}
