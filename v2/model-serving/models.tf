# ---------------------------------------------------------------------------
# Model catalog + parameterized deployment.
# Verify availability/quota before deploying:
#   az cognitiveservices model list  --location eastus2 -o table
#   az cognitiveservices usage list  --location eastus2 -o table
# ---------------------------------------------------------------------------

locals {
  model_catalog = {
    # ---- open-source / lower-cost (no Marketplace agreement) ----
    "kimi-k2" = {
      name     = "Kimi-K2.6"
      format   = "MoonshotAI"
      version  = "2026-04-20"
      sku_name = "GlobalStandard"
      capacity = 1
    }
    "deepseek-v3" = {
      name     = "DeepSeek-V3.2"
      format   = "DeepSeek"
      version  = "1"
      sku_name = "GlobalStandard"
      capacity = 1
    }
    "deepseek-v4" = {
      name     = "DeepSeek-V4-Pro"
      format   = "DeepSeek"
      version  = "2026-04-23"
      sku_name = "GlobalStandard"
      capacity = 1
    }

    # ---- GPT (OpenAI first-party, no Marketplace agreement) ----
    "gpt-5" = {
      name     = "gpt-5.4"
      format   = "OpenAI"
      version  = "2026-03-05"
      sku_name = "GlobalStandard"
      capacity = 10
    }
    "gpt-5-mini" = {
      name     = "gpt-5-mini"
      format   = "OpenAI"
      version  = "2025-08-07"
      sku_name = "GlobalStandard"
      capacity = 10
    }
    "gpt-4o" = {
      name     = "gpt-4o"
      format   = "OpenAI"
      version  = "2024-11-20"
      sku_name = "GlobalStandard"
      capacity = 10
    }

    # ---- Anthropic (REQUIRES one-time Marketplace agreement) ----
    "claude-sonnet" = {
      name     = "claude-sonnet-5"
      format   = "Anthropic"
      version  = "2"
      sku_name = "GlobalStandard"
      capacity = 1
    }
    "claude-opus" = {
      name     = "claude-opus-4-8"
      format   = "Anthropic"
      version  = "2"
      sku_name = "GlobalStandard"
      capacity = 1
    }
  }

  selected = lookup(local.model_catalog, var.model_name, null)

  model = local.selected == null ? null : {
    name     = local.selected.name
    format   = coalesce(var.model_format, local.selected.format)
    version  = coalesce(var.model_version, local.selected.version)
    sku_name = coalesce(var.sku_name, local.selected.sku_name)
    capacity = coalesce(var.sku_capacity, local.selected.capacity)
  }
}

resource "terraform_data" "validate_model" {
  lifecycle {
    precondition {
      condition     = local.selected != null
      error_message = "Unknown model_name '${var.model_name}'. Valid keys: ${join(", ", keys(local.model_catalog))}."
    }
  }
}

resource "azapi_resource" "model_deployment" {
  type      = "Microsoft.CognitiveServices/accounts/deployments@2025-06-01"
  name      = var.model_name
  parent_id = azapi_resource.foundry.id

  body = {
    sku = {
      name     = local.model.sku_name
      capacity = local.model.capacity
    }
    properties = {
      model = {
        format  = local.model.format
        name    = local.model.name
        version = local.model.version
      }
      versionUpgradeOption = "OnceNewDefaultVersionAvailable"
      raiPolicyName        = "Microsoft.DefaultV2"
    }
  }

  depends_on = [
    azapi_resource.project,
    terraform_data.validate_model,
  ]
}
