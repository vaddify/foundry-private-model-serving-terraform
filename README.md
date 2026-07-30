# Microsoft Foundry — Private Model Serving (Terraform)

> ## 🅰️ Branch: `feature/anthropic-models`
> **Purpose:** this branch focuses on deploying **Anthropic Claude** models (**Opus** & **Sonnet**)
> on the private Foundry template. It defaults `model_name` to `claude-opus`, ships the latest
> Opus/Sonnet versions (plus version-pinned alternates), and adds the Claude-specific
> `modelProviderData` attestation required by the platform.
>
> **Before deploying Claude, read [`ANTHROPIC-PREREQUISITES.md`](ANTHROPIC-PREREQUISITES.md)** —
> subscription eligibility, per-model quota (the usual blocker), the `modelProviderData`
> attestation fields (org / country / **lowercase** industry), region, and permissions.
>
> Non-Anthropic models (Kimi, DeepSeek, GPT) still work on this branch unchanged.

Terraform to deploy a **network-isolated Microsoft Foundry** environment in **East US 2**
and deploy a **model** (chosen by name) that you can serve/call privately from inside a VNet.

Priority models (open-source / lower-cost first): **Kimi, DeepSeek**, then **GPT** and **Anthropic**.

## What it creates

- Resource group
- Virtual network with two `/26` subnets (agent subnet delegated to `Microsoft.App/environments`, and a private-endpoint subnet)
- Microsoft Foundry (AI Services) account — **public access disabled**, VNet-injected, Entra-ID auth
- Private endpoint + private DNS zones (`cognitiveservices`, `services.ai`, `openai`) with VNet links
- Foundry project (system-assigned identity)
- A model deployment (parameterized by `model_name`)
- Optional agent capability host (off by default)

See [ARCHITECTURE.md](ARCHITECTURE.md) for the diagram and a resource-by-resource breakdown.
For a full, beginner-friendly walkthrough (prerequisites, deploy, calling the model, teardown,
troubleshooting), see **[GUIDE.md](GUIDE.md)**.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6 — `winget install Hashicorp.Terraform`
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) — `az login`
- Permission to create Cognitive Services accounts + deployments in the subscription
- Access into the VNet (VM, VPN, or ExpressRoute) to actually call the model, since public access is disabled

## Quick start

```bash
git clone <this-repo-url>
cd foundry-terraform

# 1. Configure
cp terraform.tfvars.example terraform.tfvars
#   edit terraform.tfvars: set subscription_id + a globally-unique foundry_account_name

# 2. Deploy
terraform init
terraform validate
terraform plan
terraform apply -auto-approve
```

## Choosing a model

Pass a catalog key (see `local.model_catalog` in [models.tf](models.tf)):

```bash
terraform apply -auto-approve -var 'model_name=deepseek-v3'
```

| Key | Model | Agreement | Notes |
|-----|-------|-----------|-------|
| `kimi-k2` | Kimi-K2.6 | none | |
| `deepseek-v3` | DeepSeek-V3.2 | none | |
| `deepseek-v4` | DeepSeek-V4-Pro | none | |
| `gpt-5` | gpt-5.4 | none | OpenAI first-party |
| `gpt-5-mini` | gpt-5-mini | none | |
| `gpt-4o` | gpt-4o | none | legacy |
| `claude-sonnet` | claude-sonnet-5 | **required** | Marketplace agreement |
| `claude-opus` | claude-opus-4-8 | **required** | Marketplace agreement |

> Model catalogs change often. A model needs **both** a current (non-deprecating) version
> **and** nonzero per-model quota. Verify with:
> ```bash
> az cognitiveservices model list --location eastus2 -o table
> az cognitiveservices usage list --location eastus2 -o table
> ```

## Region

The region is fixed to **East US 2** (`local.location` in [main.tf](main.tf)). Model availability
and quota vary by region, so keep this aligned with the region you actually have access to.

## Networking (/26 defaults)

```
VNet          192.168.0.0/24
├─ snet-agent 192.168.0.0/26   (delegated, VNet injection)
└─ snet-pe    192.168.0.64/26  (private endpoint)
```

Override in `terraform.tfvars` if needed (keep the agent subnet in RFC1918 Class B or C).

## Teardown

```bash
terraform destroy -auto-approve
```

> `destroy` pauses ~15 minutes: the delegated agent subnet holds a service link that Azure
> must release before the subnet can be deleted. A destroy-time helper waits, then purges the
> soft-deleted account. This is expected — do not interrupt it.

## Notes

- **Public access is disabled** — inference is reachable only from inside the VNet.
- **Entra-ID auth only** (`disableLocalAuth = true`) — clients authenticate with tokens (managed identity / `az login`), not API keys.
- `terraform.tfvars`, state files, and `.terraform/` are git-ignored — never commit real values.

## License

MIT — see [LICENSE](LICENSE).
