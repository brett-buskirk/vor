# Architecture

## What it is

Vör is a reproducible, single-node analytics host. One Terraform root module provisions the DigitalOcean
infrastructure, one Ansible playbook configures it, and Docker Compose runs the stack — a
[Plausible Community Edition](https://github.com/plausible/community-edition) instance backed by
PostgreSQL and ClickHouse, fronted by Caddy. A user clones the repo, sets a handful of variables, and gets
a working privacy-first analytics host that can track many sites.

The design is intentionally single-node: one droplet runs the whole stack. For personal and small-team
analytics that's the right tradeoff — cheap, reproducible, and trivial to reason about. Horizontal scale
and HA are post-1.0 considerations.

---

## Trust zones — the defining design

Every other decision follows from one fact: **analytics ingestion is public, administration is not.** A
visitor on any tracked site loads the tracking script and posts events from wherever they are in the
world, so those endpoints must live on the public internet. The dashboard, login, and site settings must
not. Caddy enforces the split across the single Plausible app.

```
             PUBLIC INTERNET                          TAILNET (zero-trust)
   ┌───────────────────────────────┐          ┌──────────────────────────────┐
   │  Any visitor, any tracked site │          │  Brett's authenticated device │
   │  GET  /js/script.js            │          │  (dashboard, login, settings) │
   │  POST /api/event               │          └───────────────┬──────────────┘
   └───────────────┬───────────────┘                          │
                   │  :443 TLS (ACME)                          │  Tailscale interface
                   ▼                                           ▼
   ┌──────────────────────────────────── droplet ───────────────────────────────────┐
   │                              ┌───────────────┐                                   │
   │   public listener  ────────► │     Caddy     │ ◄──────── tailnet listener        │
   │   (only /js/*, /api/event)   │  :80  :443    │   (everything else → dashboard)   │
   │                              └───────┬───────┘                                   │
   │                                      │  reverse proxy → plausible:8000           │
   │                              ┌───────▼───────────────┐                           │
   │                              │  Plausible CE  :8000   │                           │
   │                              │  dashboard + ingestion │                           │
   │                              └───┬───────────────┬────┘                           │
   │                internal docker   │               │   internal docker              │
   │                     ┌────────────▼───┐   ┌───────▼────────────┐                   │
   │                     │  PostgreSQL    │   │  ClickHouse        │                   │
   │                     │  :5432         │   │  :8123 / :9000     │                   │
   │                     │  accounts,     │   │  events (columnar) │                   │
   │                     │  site config   │   │                    │                   │
   │                     └────────┬───────┘   └─────────┬──────────┘                   │
   │                              └──── DO Block Storage volume ────┘                  │
   └──────────────────────────────────────────────────────────────────────────────────┘
```

The **hard requirement**: from the droplet's *public* IP, only `/js/*`, `/api/event`, and the ACME
challenge paths respond; the dashboard returns nothing (connection refused or 404) on the public
interface and is served only to requests arriving over the Tailscale interface. Proving that property —
e.g. `curl https://<public-ip>/login` fails while the same over the tailnet succeeds — is part of the
definition of done.

---

## Components

### Analytics host (droplet)

A single DigitalOcean droplet runs the full stack via Docker Compose. ClickHouse is the memory-hungry
component; the recommended floor is `s-2vcpu-4gb`. The Postgres and ClickHouse data directories live on
an attached **Block Storage volume**, so the analytics history survives a droplet rebuild or resize.

### Caddy (reverse proxy + TLS)

The perimeter. Caddy terminates TLS (automatic ACME certificates for `analytics_domain`) and enforces the
public/private split described above. It is the only container that publishes ports to the host
(`80`/`443`). Its config is the security-critical file in the repo — see `docker/plausible/Caddyfile.example`.

### Plausible CE

The analytics application, listening on `:8000` inside the Docker network. It serves both the dashboard
and the ingestion endpoints from the same process; the trust-zone split is imposed *in front of it* by
Caddy, not by Plausible itself. Configured via `plausible-conf.env` (`BASE_URL`, `SECRET_KEY_BASE`,
`TOTP_VAULT_KEY`, SMTP, `DISABLE_REGISTRATION=true`).

### PostgreSQL

Stores accounts, site configuration, and metadata (not the event stream). Internal to the Docker network;
never published. Data on the block-storage volume.

### ClickHouse

Stores the analytics events — the columnar store that makes Plausible's aggregations fast. Internal only.
Plausible ships recommended ClickHouse tuning (reduced logging, IPv4) applied via
`docker/plausible/clickhouse/`. Data on the block-storage volume.

---

## Data flow

### Ingestion path (public)

```
Visitor browser (tracked site)
   │  GET /js/script.js         (loads the tracker)
   │  POST /api/event           (sends a pageview / event)
   ▼
Caddy :443  ──public listener──►  Plausible :8000  ──►  ClickHouse (event stored)
```

### Administration path (private)

```
Brett's device (on the tailnet)
   │  dashboard / login / settings
   ▼
Caddy (tailnet listener)  ──►  Plausible :8000  ──►  PostgreSQL (config) + ClickHouse (queries)
```

---

## Network & firewall posture

The DigitalOcean Cloud Firewall (Terraform `firewall` module):

| Port | Source | Purpose |
|---|---|---|
| `80`, `443` | `0.0.0.0/0` | Public ingestion + ACME TLS (Caddy) |
| `22` | `var.ssh_allowed_ips` (required, no default) | Administration over SSH |
| everything else | denied | — |

Tailscale needs **no inbound firewall holes** — it establishes connectivity outbound (NAT traversal /
DERP). The dashboard is reached over the tailnet, not through the Cloud Firewall. PostgreSQL and
ClickHouse never bind to a public interface; they're only reachable on the internal Docker network.

---

## Variable / parameter model

A single `project_name` threads through the stack (mirroring heimdall):

| Resource | Derived value |
|---|---|
| Droplet name | `<project_name>-analytics` |
| Cloud Firewall name | `<project_name>-analytics-firewall` |
| Block storage volume | `<project_name>-data` |
| Resource tags | `[analytics, <project_name>]` |
| Project directory (on host) | `/opt/<project_name>` |

`analytics_domain` (e.g. `analytics.example.com`) drives Caddy's TLS and Plausible's `BASE_URL`.
`ssh_allowed_ips` is required with no default. See `CUSTOMIZATION.md` for the full variable reference.

---

## Design decisions

**Why not zero-public-surface like heimdall?** Because analytics ingestion is fundamentally public —
there is no way for a stranger's browser to report a pageview over a private mesh. The design goal isn't
"nothing public," it's "**only** the two ingestion paths public, everything else private." That's the
honest, defensible posture for this class of tool, and Caddy is where it's enforced.

**Why Caddy (not nginx)?** Automatic ACME TLS with near-zero config, and a readable config language for
expressing the path-based public/private split. For a single-node stack it removes a whole class of
certificate-management toil.

**Why a single node + Docker Compose (not Kubernetes)?** Simplicity and cost. One droplet running
`docker compose up -d` is reproducible, cheap, and easy to roll back. Kubernetes is overkill for a
personal/small-team analytics host.

**Why a Block Storage volume for the databases?** Analytics history *is* the product; losing it on a
droplet rebuild would be unacceptable. Putting the Postgres + ClickHouse data dirs on a separate volume
decouples data lifetime from droplet lifetime and makes backups and resizes clean.

**Why Terraform modules?** `droplet`, `firewall`, and `volume` are thin, composable wrappers that let a
user stamp out a second environment (staging/dev) without copy-paste divergence.

**Why Ansible roles (not scripts)?** Idempotency — running the playbook twice yields the same result. The
`scripts/` provide an imperative "run-by-hand" fallback that mirrors the Ansible-templated output.

**Why pin image versions?** Reproducibility. Unpinned `latest` tags mean the next deploy might pull a
breaking change. All images (Plausible, Postgres, ClickHouse, Caddy) are pinned; bumps flow through
Dependabot.
