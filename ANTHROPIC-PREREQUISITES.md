# Anthropic (Claude) Deployment — Prerequisites

This branch deploys **Anthropic Claude** models (Opus / Sonnet) on Microsoft Foundry.
Claude models have extra requirements beyond the standard model catalog. Complete these
before running `terraform apply`.

## 1. Subscription eligibility

Your Azure subscription must be **eligible to purchase the Anthropic offer** in Azure
Marketplace. Pay-as-you-go / EA subscriptions are typically eligible; sandbox, free-trial,
and some CSP/policy-restricted subscriptions are not.

- Symptom if ineligible: `Marketplace Subscription purchase eligibility check failed`.
- Verify with your subscription owner or Microsoft rep before deploying.

## 2. Region

Claude on Foundry is offered in a limited set of regions. This template is fixed to
**East US 2** (also available: Sweden Central; West US 2 has Sonnet + Opus only).
Keep the model and region aligned.

## 3. Per-model quota (the #1 blocker)

Claude quota is granted **per model** (e.g. `claude-opus-5`, `claude-sonnet-5`) and is
**0 by default**. A grant for Opus does **not** cover Sonnet.

Check current quota:

```powershell
az cognitiveservices usage list --location eastus2 -o json |
  ConvertFrom-Json |
  Where-Object { $_.name.value -match 'claude' -and $_.limit -gt 0 } |
  Select-Object @{n='quota';e={$_.name.value}}, currentValue, limit | Format-Table -AutoSize
```

- If the model you want shows `limit = 0`, request quota: Azure AI Foundry portal ->
  **Management center** -> **Quota** -> request for the specific Claude model + region.
- Symptom if missing: `InsufficientQuota ... Tokens Per Minute (thousands) - Claude <model>`.
- Terraform (`azapi`) surfaces quota problems only at apply time (no ARM preflight), sometimes
  as an opaque `400 715-123420` — check quota first.

## 4. ModelProviderData attestation (required inputs)

Anthropic deployments require a `modelProviderData` block. The Cognitive Services RP uses it to
**auto-sign the Anthropic Marketplace terms on your behalf** (no manual click-through), and the
values are sent to Anthropic with every request — set them to your **real** organization.

| Variable | Required | Notes |
|----------|----------|-------|
| `model_provider_organization_name` | **yes** | Your legal entity name |
| `model_provider_country_code` | yes (default `US`) | ISO 3166-1 alpha-2, e.g. `US`, `GB`, `DE` |
| `model_provider_industry` | yes (default `technology`) | **lowercase only**: `technology`, `finance`, `healthcare`, `education`, `retail`, `manufacturing`, `government`, `media`, `other` |

> `industry` **must be lowercase** — an uppercase value fails with
> `AnthropicOrganizationCreationException`. The template lowercases it defensively.

By deploying, you accept the [Anthropic commercial terms](https://www.anthropic.com/legal/commercial-terms).

## 5. Permissions

- Deployer needs **Contributor** (+ **User Access Administrator** or **Owner** if assigning roles).
- To call the model after deployment, the caller needs **Cognitive Services User** on the account,
  and an Entra token scoped to `https://ai.azure.com/.default`.

## 6. Tooling

- Terraform >= 1.6, Azure CLI (`az login`), providers `azurerm` + `azapi` (+ `time`).
- Deployment resource uses API **`2025-10-01-preview`** (required for `modelProviderData`).

---

## Deploy

```powershell
# From the initialized Terraform folder
terraform init
terraform apply -auto-approve `
  -var 'model_name=claude-opus' `
  -var 'model_provider_industry=technology' `
  -var 'model_provider_organization_name=Your Legal Org Name' `
  -var 'model_provider_country_code=US'
```

Model keys on this branch: `claude-opus` (opus-5), `claude-sonnet` (sonnet-5),
`claude-opus-4-8`, `claude-sonnet-4-6`.

## Verify

```powershell
terraform output
az cognitiveservices account deployment list -g <rg> -n <account> -o table
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `InsufficientQuota ... Claude <model>` | Per-model quota is 0 | Request quota for that exact model + region |
| `AnthropicOrganizationCreationException` | `industry` uppercase or a field missing | Use lowercase industry; set all three fields |
| `Marketplace Subscription purchase eligibility check failed` | Subscription not eligible for the Anthropic offer | Use an eligible subscription |
| `InvalidModelProviderData` | `modelProviderData` missing/misplaced | Ensure the three vars are set (template handles placement) |
| `400 715-123420` (opaque) | Usually insufficient quota via `azapi` | Check quota (section 3) |
