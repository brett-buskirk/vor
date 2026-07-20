# Deploying Vör

A step-by-step guide to standing up your own privacy-first analytics host — with `brett-buskirk.dev` as
the worked example. Once running, adding *more* sites needs no infrastructure change (see
[docs/ADDING-A-SITE.md](docs/ADDING-A-SITE.md)).

The whole thing is roughly a 30-minute exercise: `terraform apply` provisions the droplet, firewall, and
data volume; `ansible-playbook` hardens the host, installs Docker + Tailscale, and brings up the stack;
then you create your first admin over Tailscale and add a site.

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

**a. Match the Ansible variables to your Terraform config.** Copy the group-vars
template (the real `all.yml` is gitignored — it holds your values), then edit it:

```bash
cp ansible/inventory/group_vars/all.yml.example ansible/inventory/group_vars/all.yml
```

| Variable | Set to | Notes |
|---|---|---|
| `project_name` | same value as `terraform.tfvars` | derives `/opt/<project_name>` + the volume mount |
| `analytics_domain` | e.g. `analytics.brett-buskirk.dev` | must match Terraform and `BASE_URL` |
| `caddy_acme_email` | your email | ACME contact for the public TLS certificate |

`public_ip` defaults to the inventory host address, and the dashboard's tailnet URL is set up automatically once the
node joins the tailnet — you don't set either by hand.

**b. Fill in the Plausible secrets.** Copy the env template and generate the secrets:

```bash
cp docker/plausible/plausible-conf.env.example docker/plausible/plausible-conf.env
openssl rand -base64 48   # -> SECRET_KEY_BASE
openssl rand -base64 32   # -> TOTP_VAULT_KEY
```

Then edit `docker/plausible/plausible-conf.env`:
- `BASE_URL=https://analytics.brett-buskirk.dev`
- `SECRET_KEY_BASE` / `TOTP_VAULT_KEY` — the values you just generated
- `POSTGRES_PASSWORD` **and** the password embedded in `DATABASE_URL` — set both to the *same* strong
  value (Postgres reads the first, Plausible connects with the second; they must match)
- SMTP settings — for invites, password resets, and email reports
- Leave `DISABLE_REGISTRATION=true` for now; you flip it once to create your admin (Step 5)

**c. Point the inventory at the droplet:**

```bash
cp ansible/inventory/manual.yml.example ansible/inventory/manual.yml
# Set ansible_host to the droplet's public IP (terraform output droplet_ip)
```

**d. Install the Ansible dependencies, then run the playbook.** The playbook builds on the
`brett-buskirk.baseline` role (installed from Galaxy) — it creates a `deploy` sudo user, hardens the host,
installs Docker + Tailscale (joining the tailnet with your auth key), and brings up the stack:

```bash
ansible-galaxy install -r ansible/requirements.yml
ansible-playbook -i ansible/inventory/manual.yml ansible/playbooks/site.yml \
  -e "tailscale_auth_key=tskey-auth-xxxx"
```

`plausible-conf.env` and `manual.yml` are gitignored; the Tailscale auth key is a secret passed at runtime
— never commit it. (The deploy still connects as root; the `deploy` user is created for later hardening.)

> **Tip — dodge Let's Encrypt rate limits while testing.** Set `caddy_acme_staging: true` in
> `group_vars/all.yml` for your first runs so Caddy uses the ACME *staging* CA (untrusted certs, but no
> rate limit). Flip it back to `false` and re-run for the real, browser-trusted certificate.

---

## Step 4 — Join the tailnet and reach the dashboard

The dashboard is reached over your tailnet, with a real HTTPS cert, via **Tailscale Serve**. Full detail
(and *why* — the CSRF/cookie/LiveView constraints that rule out the simpler options) is in
**[docs/DASHBOARD-ACCESS.md](docs/DASHBOARD-ACCESS.md)**. The short version:

1. **Enable HTTPS certs for your tailnet** (once): Tailscale admin console → **DNS** → enable **MagicDNS**
   and **HTTPS Certificates**.
2. **The playbook already ran `tailscale serve`** for you (the `plausible` role). Confirm the dashboard URL
   from the droplet: `tailscale serve status` → e.g. `https://vor-analytics.<your-tailnet>.ts.net/`.
3. **Put the device you browse from on the tailnet** too (Tailscale is a mesh — WSL2 users install the
   **Windows** client). Then open that `https://<droplet>.<tailnet>.ts.net/` URL. Real cert, no warning.

> **Turn off any full-tunnel VPN (e.g. NordVPN) when using the tailnet.** It hijacks the Tailscale IP range
> and will make both the dashboard and Tailscale SSH unreachable. See docs/DASHBOARD-ACCESS.md.

Confirm the public/private split works as designed:

```bash
curl -I https://analytics.brett-buskirk.dev/js/script.js   # public: 200
curl -I https://<droplet-public-ip>/login                  # public dashboard: should FAIL / 404
# the dashboard responds only over the tailnet URL above
```

---

## Step 5 — Create your first admin

Vör ships with `DISABLE_REGISTRATION=true`, so there's no open sign-up. You create the first account with
a one-time flip — and because the registration page lives on the dashboard, this happens **over
Tailscale**, never on the public internet:

1. In `docker/plausible/plausible-conf.env`, set `DISABLE_REGISTRATION=false`.
2. Re-run the playbook — it copies the changed env up and recreates the Plausible container.
3. Open the dashboard at its tailnet URL (Step 4) and register your admin account at `/register`.
4. Set `DISABLE_REGISTRATION=invite_only` (lets you invite teammates later) or `true` (fully closed), and
   re-run the playbook once more. Registration is now locked again.

There is no first-user CLI in Community Edition — the register-then-lock flow above is the supported path.

---

## Step 6 — Add your first site

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

Back up the databases — see **[docs/BACKUP.md](docs/BACKUP.md)** for the strategy (volume snapshots plus
`scripts/backup.sh` logical dumps) and the restore procedure.

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
