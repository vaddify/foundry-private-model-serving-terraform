output "account_kind" {
  description = "Sanity check on the target. Must be 'AIServices' for this to be a Foundry account."
  value       = data.azapi_resource.account.output.kind
}

output "account_public_network_access" {
  description = "If this is 'Disabled', a public MCP target may be unreachable and a failure could be networking, not the hypothesis."
  value       = data.azapi_resource.account.output.properties.publicNetworkAccess
}

output "project_endpoint" {
  description = "Foundry project endpoint. Feed this to `azd ai project set`."
  value       = local.project_endpoint
}

output "connection_id" {
  description = "ARM resource ID of the MCP connection. If this exists, the RP accepted the connection with no agent present."
  value       = azapi_resource.mcp_connection.id
}

output "connection_category_sent" {
  description = "Category value submitted. Compare against connection_readback - the RP may rewrite it."
  value       = var.mcp_connection_category
}

output "connection_readback" {
  description = "Full RP response, including fields it defaulted or rewrote. The finding lives here."
  value       = azapi_resource.mcp_connection.output
  sensitive   = true
}

output "next_steps" {
  description = "Commands to run after apply to complete the validation."
  value       = <<-EOT

    Terraform has proved half the hypothesis: the connection resource was created
    on an existing project without creating an agent. To prove it is consumable:

      pwsh ./validate.ps1 -ProjectEndpoint "${local.project_endpoint}" `
                          -SubscriptionId "${var.subscription_id}" `
                          -ResourceGroup "${var.resource_group_name}" `
                          -AccountName "${var.account_name}" `
                          -ProjectName "${var.project_name}" `
                          -ConnectionName "${var.connection_name}"

    Remove ONLY the connection when finished (nothing else was created):

      terraform destroy

  EOT
}
