# ---------------------------------------------------------------------------
# Destroy-time helper.
# The agent subnet is delegated to Microsoft.App/environments and gets a
# serviceAssociationLink when the Foundry account is created. On destroy this
# causes "InUseSubnetCannotBeDeleted". This waits for the backend to release
# the link, then purges the soft-deleted account so the subnet can be removed.
# Only runs during `terraform destroy`.
# ---------------------------------------------------------------------------

resource "time_sleep" "purge_ai_foundry_cooldown" {
  destroy_duration = "900s"

  depends_on = [azurerm_subnet.subnet_agent]
}

resource "azapi_resource_action" "purge_ai_foundry" {
  type        = "Microsoft.CognitiveServices/locations/resourceGroups/deletedAccounts@2021-04-30"
  resource_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.CognitiveServices/locations/${local.location}/resourceGroups/${var.resource_group_name}/deletedAccounts/${var.foundry_account_name}"
  method      = "DELETE"
  when        = "destroy"

  depends_on = [time_sleep.purge_ai_foundry_cooldown]
}
