output "network_resource_group_name" {
  description = "Resource group holding the shared network."
  value       = azurerm_resource_group.network.name
}

output "vnet_name" {
  value = azurerm_virtual_network.vnet.name
}

output "vnet_id" {
  value = azurerm_virtual_network.vnet.id
}

output "pe_subnet_name" {
  value = azurerm_subnet.pe.name
}

output "pe_subnet_id" {
  value = azurerm_subnet.pe.id
}

output "private_dns_zone_names" {
  description = "Map of the shared private DNS zone names."
  value       = { for k, z in azurerm_private_dns_zone.zones : k => z.name }
}
