# Vör

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Self-hosted, privacy-first web analytics for DigitalOcean — a cookieless [Plausible](https://plausible.io) instance on a Tailscale-secured droplet, provisioned with Terraform + Ansible + Docker Compose.**

One `terraform apply` and one `ansible-playbook` run give you your own analytics host: the sub-1 KB
tracking script and event API are public over TLS, while the admin dashboard is reachable **only over
[Tailscale](https://tailscale.com/)**. Track one site or many from a single instance — with no cookies,
no consent banner, and no third party in the loop.

> Not an engineer? Read the [plain-language overview](docs/ABOUT.md) — what Vör is and why it exists, no jargon.

> **Status:** deployed. A live instance runs in production on DigitalOcean and tracks the sites listed
> under [Live instance](#live-instance) below, stood up with a single `terraform apply` + `ansible-playbook`
> run. Tagging `v1.0.0` is the last milestone (see [ROADMAP.md](ROADMAP.md)).

---

## Why Vör

Analytics without the Google Analytics baggage — no heavy script, no third-party cookies, no
consent-banner overhead, no handing visitor data to an ad company. [Plausible](https://plausible.io) is
open source, cookieless, and privacy-first by design; Vör is the infrastructure that runs it **on your
own droplet**, as code, so the data never leaves your control.

- **Cookieless & lightweight** — sub-1 KB script, no consent banner needed in most jurisdictions.
- **Multi-site from day one** — track several properties from one instance; adding a site needs **zero
  infrastructure changes**.
- **Private by default** — the dashboard is Tailscale-only; only the tracking script and event endpoint
  are public.
- **Reproducible** — the whole stack is Terraform + Ansible + Docker Compose. Clone, set a few variables,
  deploy.

---

## What it deploys

**Infrastructure (Terraform):**
- A DigitalOcean droplet — the analytics host
- A Cloud Firewall — public `80`/`443` for ingestion + TLS, SSH restricted to your IPs, nothing else
- A Block Storage volume — holds the Postgres + ClickHouse data so analytics history survives a rebuild

**Analytics stack (Ansible + Docker Compose):**

| Component | Role | Exposure |
|---|---|---|
| Plausible CE | The analytics app (dashboard + ingestion), `:8000` | Split — see below |
| PostgreSQL | Accounts, site config, metadata | Internal only |
| ClickHouse | The analytics events (columnar store) | Internal only |
| Caddy | Reverse proxy + automatic TLS | Public `:80`/`:443` |

**Access model — the deliberate split:** analytics ingestion is inherently public (visitors everywhere
load the script and post events), but the admin dashboard is not. Caddy serves **only** the tracking
script (`/js/*`) and event API (`/api/event`) to the public internet over TLS; the **dashboard, login,
and settings are bound to the Tailscale interface** and never reachable from the public IP. Postgres and
ClickHouse stay on the internal Docker network.

---

## Architecture

```
   Visitors (any tracked site)                     You (admin)
            │                                           │
   GET /js/script.js                              Tailscale (zero-trust)
   POST /api/event                                       │
            │  public :443 (TLS)                         │  tailnet only
            ▼                                            ▼
   ┌───────────────────────────── DigitalOcean droplet ─────────────────────────────┐
   │  ┌─────────┐   public: /js/*, /api/event    ┌──────────────────────────────┐   │
   │  │  Caddy  │ ─────────────────────────────► │  Plausible CE  :8000          │   │
   │  │ :80/443 │   tailnet: dashboard, /login   │  (dashboard + ingestion)      │   │
   │  └─────────┘ ◄───────────────────────────── └──────────────┬───────────────┘   │
   │                                                             │  internal network │
   │                              ┌──────────────┐   ┌───────────▼──────────────┐    │
   │                              │ PostgreSQL   │   │ ClickHouse               │    │
   │                              │ (metadata)   │   │ (events)                 │    │
   │                              └──────┬───────┘   └───────────┬──────────────┘    │
   │                                     └─────── Block Storage volume ──────┘       │
   └────────────────────────────────────────────────────────────────────────────────┘
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full component map, trust-zone model, and design decisions.

---

## Prerequisites

- DigitalOcean account with an API token
- SSH key registered with DigitalOcean (`doctl compute ssh-key list`)
- A DNS record you control for the analytics domain (e.g. `analytics.example.com`)
- Tailscale account (free tier is sufficient)
- Local tools: `terraform >= 1.0`, `ansible >= 2.12`, `doctl`

---

## Quick start

The detailed, step-by-step guide — with `brett-buskirk.dev` as a worked example — is in
**[CUSTOMIZATION.md](CUSTOMIZATION.md)**. The summary:

```bash
# 0. Clone, configure, and preflight
git clone https://github.com/brett-buskirk/vor.git && cd vor
cp terraform/environments/example/terraform.tfvars.example \
   terraform/environments/example/terraform.tfvars
# Edit terraform.tfvars — required: do_token, project_name, analytics_domain,
#   ssh_fingerprints, ssh_allowed_ips
./scripts/preflight.sh

# 1. Provision infrastructure
cd terraform/environments/example && terraform init && terraform apply

# 2. cp the group-vars + env templates to their real (gitignored) names, set
#    project_name + analytics_domain, fill the secrets, point the inventory, then:
ansible-galaxy install -r ansible/requirements.yml
ansible-playbook -i ansible/inventory/manual.yml ansible/playbooks/site.yml \
  -e "tailscale_auth_key=tskey-auth-xxxx"

# 3. Point analytics.<your-domain> at the droplet IP, then open the dashboard over Tailscale
```

Put **your own device** on the same tailnet (Tailscale is a mesh — the machine you browse from needs it
too; WSL2 users install the *Windows* client), then open the dashboard at the droplet's Tailscale
hostname. See [CUSTOMIZATION.md](CUSTOMIZATION.md) for the full walkthrough.

---

## Adding a site

Adding a second (or tenth) tracked property requires **no infrastructure change** — you add the site in
Plausible's own dashboard and drop its script tag into that site's repo. Full workflow in
**[docs/ADDING-A-SITE.md](docs/ADDING-A-SITE.md)**.

---

## Security model

Only two paths are public: the tracking script (`/js/*`) and the event API (`/api/event`), both over TLS.
The **admin dashboard is Tailscale-only** — authenticated, encrypted, and never exposed on the public IP.
SSH is restricted to the IPs in `ssh_allowed_ips` (required, no default). PostgreSQL and ClickHouse are
never published off the internal Docker network. See [SECURITY.md](SECURITY.md).

---

## Live instance

This repo runs Brett Buskirk's own privacy-first analytics. The instance currently tracks:

- **[brett-buskirk.dev](https://brett-buskirk.dev)** — the contracting site + blog

Adding another site needs no infrastructure change — see [docs/ADDING-A-SITE.md](docs/ADDING-A-SITE.md).

---

## Documentation

| Document | Purpose |
|---|---|
| [CUSTOMIZATION.md](CUSTOMIZATION.md) | Step-by-step deployment guide + teardown runbook |
| [docs/ADDING-A-SITE.md](docs/ADDING-A-SITE.md) | Add a tracked property (no infra change) |
| [docs/DASHBOARD-ACCESS.md](docs/DASHBOARD-ACCESS.md) | Reaching the admin dashboard over Tailscale (Serve + real HTTPS) |
| [docs/BACKUP.md](docs/BACKUP.md) | Backup & restore — volume snapshots + logical dumps |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Component map, trust zones, design decisions |
| [docs/ABOUT.md](docs/ABOUT.md) | Plain-language overview — no jargon |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Workflow, validation gates, conventions |
| [SECURITY.md](SECURITY.md) | Vulnerability reporting and security posture |
| [docs/SECURITY-REVIEW.md](docs/SECURITY-REVIEW.md) | Threat model & review of the firewall + Caddy split |
| [ROADMAP.md](ROADMAP.md) | Planned phases and post-1.0 ideas |

---

Built by [Brett Buskirk LLC](https://brett-buskirk.dev) · MIT License
