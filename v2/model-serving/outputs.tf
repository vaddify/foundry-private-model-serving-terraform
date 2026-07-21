output "resource_group_name" {
  value = azurerm_resource_group.serve.name
}

output "foundry_account_name" {
  value = azapi_resource.foundry.name
}

output "foundry_endpoint" {
  value = try(azapi_resource.foundry.output.properties.endpoint, null)
}

output "project_name" {
  value = azapi_resource.project.name
}

output "deployed_model_name" {
  value = azapi_resource.model_deployment.name
}

output "deployed_model_details" {
  value = local.model
}
