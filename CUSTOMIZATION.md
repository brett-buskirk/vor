# Deploying Vör

A step-by-step guide to standing up your own privacy-first analytics host — with `brett-buskirk.dev` as
the worked example. Once running, adding *more* sites needs no infrastructure change (see
[docs/ADDING-A-SITE.md](docs/ADDING-A-SITE.md)).

> **Scaffold note:** the repo currently ships the *shape* of the deployment (stubs + this guide). Steps
> that run Terraform/Ansible finalize as those layers are implemented (see [ROADMAP.md](ROADMAP.md)).
> The workflow below is the target and won't change materially.

---

## Prerequisites

- A **DigitalOcean** account and an API token (`doctl auth init`, or generate a token in the control panel).
- An **SSH key registered with DigitalOcean** — grab its fingerprint with `doctl compute ssh-key list`.
- A **DNS record you control** for the analytics domain (e.g. an `A` record for
  `analytics.brett-buskirk.dev`). You'll point it at the droplet after `terraform apply`.
- A **Tailscale** account (free tier is fine) and a Tailscale **auth key** for unattended node join.
- Local tools: `terraform >= 1.0`, `ansible >= 2.12`, `doctl`, and the Tailscale client on the device
  you'll browse from.

Run the preflight check to confirm your toolchain and config:

```bash
./scripts/preflight.sh
```

---

## Step 1 — Configure Terraform

```bash
cp terraform/environments/example/terraform.tfvars.example \
   terraform/environments/example/terraform.tfvars
```

Edit `terraform.tfvars`. Required and key optional variables:

| Variable | Required | Example | Notes |
|---|---|---|---|
| `do_token` | ✅ | `dop_v1_…` | DigitalOcean API token. **Secret** — the file is gitignored. |
| `project_name` | ✅ | `vor` | Threads through all resource names (`<project_name>-analytics`, …). |
| `analytics_domain` | ✅ | `analytics.brett-buskirk.dev` | Drives Caddy TLS + Plausible `BASE_URL`. |
| `ssh_fingerprints` | ✅ | `["aa:bb:…"]` | Registered DO SSH key(s) for droplet access. |
| `ssh_allowed_ips` | ✅ | `["203.0.113.4/32"]` | SSH source allow-list. **No default; never `0.0.0.0/0`.** |
| `region` | — | `nyc3` | Defaults to `nyc3`. |
| `droplet_size` | — | `s-2vcpu-4gb` | Floor for ClickHouse. Larger for higher traffic. |
| `volume_size_gb` | — | `50` | Block-storage volume for the databases. |

**Never commit `terraform.tfvars`** — only the `.example`. Verify with `git status`.

---

## Step 2 — Provision infrastructure

```bash
cd terraform/environments/example
terraform init
terraform plan      # review — one droplet, one firewall, one volume
terraform apply
```

Note the outputs (the droplet's public IP especially). Then **create/point the DNS record**:
`analytics.brett-buskirk.dev` → the droplet's public IP. TLS won't issue until DNS resolves.

---

## Step 3 — Configure the analytics stack

Copy the Plausible env template and fill it in:

```bash
cp docker/plausible/plausible-conf.env.example docker/plausible/plausible-conf.env
# Generate the secrets:
openssl rand -base64 48   # -> SECRET_KEY_BASE
openssl rand -base64 32   # -> TOTP_VAULT_KEY
# Set BASE_URL=https://analytics.brett-buskirk.dev, SMTP settings, DISABLE_REGISTRATION=true
```

Point the Ansible inventory at the droplet:

```bash
cp ansible/inventory/manual.yml.example ansible/inventory/manual.yml
# Set the droplet IP under the `analytics` host
```

Then run the playbook — it hardens the host, installs Docker + Tailscale, and brings up the stack:

```bash
ansible-playbook -i ansible/inventory/manual.yml ansible/playbooks/site.yml
```

`plausible-conf.env` and `manual.yml` are both gitignored.

---

## Step 4 — Join the tailnet and reach the dashboard

Tailscale is a mesh, so the device you browse from needs it too:

- Install the Tailscale client on your machine and `tailscale up` (WSL2 users: install the **Windows**
  client — the tailnet lives on the host).
- Find the droplet on the tailnet: `tailscale status`.
- Open the Plausible dashboard at the droplet's **Tailscale** hostname/IP.

Confirm the split works as designed:

```bash
curl -I https://analytics.brett-buskirk.dev/js/script.js   # public: 200
curl -I https://<droplet-public-ip>/login                  # public dashboard: should FAIL / 404
# the dashboard should only respond over the tailnet
```

---

## Step 5 — Add your first site

In the dashboard, **+ Add website** → `brett-buskirk.dev`, and add the snippet to that site's repo. Full
workflow (and the estate note about `brett-buskirk-dev` issue #4) in
[docs/ADDING-A-SITE.md](docs/ADDING-A-SITE.md).

---

## Maintenance

```bash
# Update stack images on the host
ssh root@<droplet-ip>
cd /opt/<project_name>
docker compose pull && docker compose up -d

# Tail a service's logs
docker compose logs -f plausible
```

Back up the databases (see `scripts/backup.sh` — `pg_dump` + ClickHouse export, optionally to Spaces).

---

## Teardown

```bash
# 1. Stop the stack and leave the tailnet
ssh root@<droplet-ip> "cd /opt/<project_name> && docker compose down && tailscale logout"

# 2a. Destroy compute + firewall, KEEP the data volume
cd terraform/environments/example
terraform destroy -target=module.droplet -target=module.firewall

# 2b. Full teardown INCLUDING the data volume (this deletes your analytics history)
terraform destroy
```

Back up first if you want to keep the history — destroying the volume is irreversible. Remove local state
and secret files (`terraform.tfstate*`, `terraform.tfvars`, `plausible-conf.env`) once you're done.
