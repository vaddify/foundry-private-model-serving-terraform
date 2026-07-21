# v2 — Model Serving (lean, private)

This branch delivers the **model serving** Foundry instance only. It is intentionally lean:
**private endpoint + private DNS zones, no agent subnet, no `networkInjections`, no capability
host, no purge helper.**

Agent services will be a **separate** Foundry instance deployed later. The single
agent-delegated subnet (one per VNet) is **reserved for that instance** and is deliberately
**out of scope** here — this template never creates it or uses VNet injection.

## Roots

- **`network/`** — shared VNet, private-endpoint subnet (`snet-pe`), and the 3 private DNS zones.
  Does **not** create the agent subnet (reserved for the future agent instance).
- **`model-serving/`** — Foundry account (public access disabled, Entra-ID auth), private
  endpoint into `snet-pe`, project, and a parameterized model deployment. No VNet injection.

```
rg-foundry-network   → VNet, 3 private DNS zones, snet-pe        (network/)
rg-foundry-serve     → serving account + PE + model deployment   (model-serving/)
```

Region is fixed to **East US 2** in each root. The agent subnet range (e.g. `192.168.0.0/26`)
is left unallocated so the future agent instance can claim it.

## Apply order (separate state per root)

Apply `network` first; `model-serving` references it by name via `data` sources.

```bash
# 1) Shared network
cd network
cp terraform.tfvars.example terraform.tfvars   # set subscription_id
terraform init && terraform apply -auto-approve
cd ..

# 2) Model serving (lean)
cd model-serving
cp terraform.tfvars.example terraform.tfvars   # set subscription_id + unique account name
terraform init && terraform apply -auto-approve
```

## Destroy order (reverse)

```bash
cd model-serving && terraform destroy -auto-approve
cd ../network && terraform destroy -auto-approve
```

> No agent subnet here, so there is **no ~15-minute purge delay** on destroy.

## Choosing a model

```bash
cd model-serving
terraform apply -auto-approve -var 'model_name=deepseek-v3'
```

Verify versions/quota first with `az cognitiveservices model list --location eastus2 -o table`
and `az cognitiveservices usage list --location eastus2 -o table`. See `model-serving/models.tf`
for the catalog keys.

## Notes

- **Shared DNS zones**: created once in `network/`; the private endpoint attaches to them.
- **Separate state** per root; use a remote backend (Azure Storage + locking) for team use.
- **Auth**: account uses `disableLocalAuth = true` (Entra-ID tokens only) and disabled public
  access — reach it from inside the VNet.
- The original single-instance template remains unchanged at the repository root.
