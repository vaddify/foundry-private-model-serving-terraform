# v2 — Split Foundry Instances (model serving + agent services)

This iteration separates the workloads into **two Foundry accounts** sharing one network:

- **`network/`** — shared VNet, private-endpoint subnet (`snet-pe`), and the 3 private DNS zones.
- **`model-serving/`** — LEAN Foundry account (PE + DNS only). **No** agent subnet, **no**
  `networkInjections`, **no** capability host, **no** purge helper.
- **`agent-services/`** — Foundry account **with** the agent-delegated subnet (`snet-agent`),
  `networkInjections`, project capability host, and the destroy-time purge helper.

The single agent-delegated subnet is created and owned by `agent-services`, so it stays
**reserved exclusively for agents**. Both instances share the DNS zones and PE subnet.

```
rg-foundry-network   → VNet, 3 private DNS zones, snet-pe        (network/)
rg-foundry-serve     → serving account + PE + model deployment   (model-serving/)
rg-foundry-agent     → agent account + snet-agent + injection    (agent-services/)
                        + capability host + purge
```

Region is fixed to **East US 2** in each root.

## Apply order (state is separate per root)

Each folder is an independent Terraform root with its **own state**. Apply `network` first;
the other two reference it by name via `data` sources.

```bash
# 1) Shared network (must be first)
cd network
cp terraform.tfvars.example terraform.tfvars   # set subscription_id
terraform init && terraform apply -auto-approve
cd ..

# 2) Model serving (lean)
cd model-serving
cp terraform.tfvars.example terraform.tfvars   # set subscription_id + unique account name
terraform init && terraform apply -auto-approve
cd ..

# 3) Agent services (adds the agent subnet + injection + capability host)
cd agent-services
cp terraform.tfvars.example terraform.tfvars   # set subscription_id + unique account name
terraform init && terraform apply -auto-approve
```

> Apply the instance roots **sequentially**, not in parallel — both create subnets in the same
> shared VNet, and concurrent VNet writes can conflict.

## Destroy order (reverse)

```bash
cd agent-services && terraform destroy -auto-approve   # ~15 min (agent subnet purge)
cd ../model-serving && terraform destroy -auto-approve
cd ../network && terraform destroy -auto-approve
```

## Notes / best practices

- **Shared DNS zones**: created once in `network/`; both private endpoints attach to them. Do not
  recreate identical zones per instance (only one link per zone per VNet is allowed).
- **Separate state**: use a remote backend (Azure Storage + locking) with one state file per root
  in a team setting. Serving and agents must never share state.
- **Model catalog**: `model-serving/models.tf` — verify versions/quota with
  `az cognitiveservices model list` / `usage list` before deploying.
- **Auth**: both accounts use `disableLocalAuth = true` (Entra-ID tokens only) and disabled public
  access — reach them from inside the VNet.
- The original single-instance template remains unchanged at the repository root.
