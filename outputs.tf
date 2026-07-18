output "resource_group_name" {
  description = "Resource group holding the Foundry account."
  value       = azurerm_resource_group.this.name
}

output "foundry_account_name" {
  description = "Name of the Microsoft Foundry account."
  value       = azapi_resource.foundry.name
}

output "foundry_endpoint" {
  description = "Foundry account endpoint (base URL for inference & control plane)."
  value       = try(azapi_resource.foundry.output.properties.endpoint, null)
}

output "project_name" {
  description = "Name of the Foundry project."
  value       = azapi_resource.project.name
}

output "deployed_model_name" {
  description = "The deployment name (used as the model identifier in API calls)."
  value       = azapi_resource.model_deployment.name
}

output "deployed_model_details" {
  description = "Resolved model format/version/sku that was deployed."
  value       = local.model
}
