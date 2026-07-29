# ---------------------------------------------------------------------------
# STEP 3 - Deploy a model (model name passed as a parameter: var.model_name)
#
# The catalog below pre-fills format/version/sku for the in-scope models so
# callers only need to pass the model_name. Priority order (open-source /
# lower-cost first): Kimi, DeepSeek, MiniMax -> then GPT & Anthropic.
#
# IMPORTANT: Model catalog entries (versions, SKUs, availability per region)
# change frequently. Verify with:
#   az cognitiveservices model list --location eastus2 -o table
# Some models (Anthropic, and certain serverless/MaaS models) require a
# one-time Azure Marketplace agreement acceptance on the subscription before
# a deployment will succeed.
# ---------------------------------------------------------------------------

locals {
  model_catalog = {
    # =======================================================================
    # Verified in East US 2 on 2026-07-18.
    # A model needs BOTH: (a) a current (non-deprecating) version, and
    # (b) nonzero per-model quota in the subscription. Check with:
    #   az cognitiveservices model list --location eastus2 -o table
    #   az cognitiveservices usage list --location eastus2 -o table
    # =======================================================================

    # ---- Priority 1: open-source / lower-cost (no Marketplace agreement) ----
    "kimi-k2" = {
      name     = "Kimi-K2.6"
      format   = "MoonshotAI"
      version  = "2026-04-20"
      sku_name = "GlobalStandard"
      capacity = 1 # quota limit 100
    }
    "deepseek-v3" = {
      name     = "DeepSeek-V3.2"
      format   = "DeepSeek"
      version  = "1"
      sku_name = "GlobalStandard"
      capacity = 1 # quota limit 1000
    }
    "deepseek-v4" = {
      name     = "DeepSeek-V4-Pro"
      format   = "DeepSeek"
      version  = "2026-04-23"
      sku_name = "GlobalStandard"
      capacity = 1 # quota limit 1000
    }
    # NOTE: DeepSeek-R1 is deprecating and BLOCKED for new deployments.
    # NOTE: MiniMax is not available in East US 2 as of 2026-07-18.

    # ---- Priority 2: GPT (OpenAI first-party, no Marketplace agreement) ----
    "gpt-5" = {
      name     = "gpt-5.4"
      format   = "OpenAI"
      version  = "2026-03-05"
      sku_name = "GlobalStandard"
      capacity = 10 # quota limit 3000 (gpt-5.5/5.6 have 0 quota here)
    }
    "gpt-5-mini" = {
      name     = "gpt-5-mini"
      format   = "OpenAI"
      version  = "2025-08-07"
      sku_name = "GlobalStandard"
      capacity = 10 # quota limit 1000
    }
    "gpt-4o" = {
      name     = "gpt-4o"
      format   = "OpenAI"
      version  = "2024-11-20"
      sku_name = "GlobalStandard"
      capacity = 10 # quota limit 450 (legacy; deprecates 2026-10-01)
    }

    # ---- Anthropic (BRANCH FOCUS) - REQUIRES a one-time Marketplace agreement ----
    # Verified in East US 2 on 2026-07-29. Anthropic models bill under the shared
    # "MaaS" quota bucket. Accept the model's Marketplace terms in the portal
    # (Model catalog -> the Claude model -> Agree) before the first deployment,
    # otherwise apply fails with a terms/agreement error.
    "claude-opus" = {
      name     = "claude-opus-5"
      format   = "Anthropic"
      version  = "2"
      sku_name = "GlobalStandard"
      capacity = 1
    }
    "claude-sonnet" = {
      name     = "claude-sonnet-5"
      format   = "Anthropic"
      version  = "2"
      sku_name = "GlobalStandard"
      capacity = 1
    }
    # Version-pinned alternates (use if you need a specific release):
    "claude-opus-4-8" = {
      name     = "claude-opus-4-8"
      format   = "Anthropic"
      version  = "2"
      sku_name = "GlobalStandard"
      capacity = 1
    }
    "claude-sonnet-4-6" = {
      name     = "claude-sonnet-4-6"
      format   = "Anthropic"
      version  = "1"
      sku_name = "GlobalStandard"
      capacity = 1
    }
  }

  # Fail early with a clear message if an unknown model key is passed.
  selected = lookup(local.model_catalog, var.model_name, null)

  model = local.selected == null ? null : {
    name     = local.selected.name
    format   = coalesce(var.model_format, local.selected.format)
    version  = coalesce(var.model_version, local.selected.version)
    sku_name = coalesce(var.sku_name, local.selected.sku_name)
    capacity = coalesce(var.sku_capacity, local.selected.capacity)
  }
}

# Guard: unknown model name -> readable error at plan time.
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
