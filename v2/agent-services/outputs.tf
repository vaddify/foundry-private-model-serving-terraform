output "resource_group_name" {
  value = azurerm_resource_group.agent.name
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

output "agent_subnet_id" {
  value = azurerm_subnet.agent.id
}

output "capability_host_enabled" {
  value = var.enable_capability_host
}
