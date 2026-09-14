# CLAUDE.md — Vör

Working manual **and** build brief for the Claude Code agent developing **this** repo. Read it top to
bottom before touching anything. Two parent files auto-load above it via the directory walk and own the
universal rules — this file does **not** restate them:

- **`/etc/claude-code/CLAUDE.md`** (machine policy) — the chain of command (branch → PR → **Brett
  merges**; never self-merge, never commit to `main`), signed commits, the safety floors, brand
  positioning, NIST AI RMF alignment.
- **`~/github-repos/CLAUDE.md`** (estate manual) — issue/PR wiring (assignee `brett-buskirk`, labels,
  milestone, linked in Linear), the `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
  commit trailer, the AgentGate `dangerous_patterns`-fires-in-prose quirk, the `brett-buskirk`-must-be-
  the-active-`gh`-account gotcha, and the estate memory.

Everything below is Vör-specific.

---

## What Vör is

**Vör** (the Norse goddess said to know all things, from whom nothing can be hidden) is a **self-hosted,
privacy-first web-analytics stack** for Brett's web properties. It stands up a single **[Plausible
Community Edition](https://github.com/plausible/community-edition)** instance on a DigitalOcean droplet —
provisioned with **Terraform**, configured with **Ansible**, run with **Docker Compose**, and
administered over **Tailscale** — and tracks one or more sites from that one instance.

Plausible was chosen deliberately over Google Analytics: open source, **cookieless**, sub-1 KB script,
no personal-data collection, and no consent banner needed in most jurisdictions. That matches the
"minimal, fast, privacy-conscious" ethos of Brett's sites. The first tracked property is
`brett-buskirk.dev`; more (e.g. `helm.brett-buskirk.dev`) join later **without any infrastructure
change** — that multi-site-from-day-one property is a core design goal, not an afterthought.

**Positioning.** Like `heimdall` and `agent-gate`, Vör is both a **real tool** Brett runs and a
**portfolio piece** — "here's the privacy-first analytics foundation I deploy, as code." It's public and
MIT-licensed (once it goes live; see *Visibility* below). Treat every reader as a potential client: the
docs should sell the rigor.

## Provenance — greenfield, generic from day one

Unlike `heimdall` (which began as a real single-tenant production deployment, `rcj-infra`, and was
*generalized afterward*), **Vör starts generic and multi-site-aware from the first commit.** There is no
org-specific deployment to strip out. Don't hardcode `brett-buskirk.dev` anywhere in the shipped
template — it's just the *first* configured site, set via variables, exactly like any other. A stranger
should be able to clone Vör, set a handful of variables, and get their own privacy-first analytics host.

**Also know:** as of July 2026 Brett has **no other active droplets** — his live properties are
DigitalOcean *Apps* (static builds, GitOps-deployed), not VMs. Vör's droplet is likely the **first
persistent VM** in his current personal infrastructure. Terraform starts from a **clean slate** — do
**not** assume an existing VPC, Tailscale tailnet, DNS zone, or firewall baseline to attach to. The
*pattern* to follow is proven (via `heimdall`); the *resources* are all net-new here.

---

## ⚠️ The defining design decision — read this twice

`heimdall` is **zero-public-surface**: every management port is Tailscale-only, nothing is exposed to the
internet. **Vör cannot be fully zero-public-surface, and that's the whole architectural challenge.**

Analytics ingestion is inherently public: a visitor on *any* tracked site, anywhere in the world, loads
the tracking script and `POST`s an event. That endpoint **must** be reachable on the public internet.
But the **admin dashboard** (login, site settings, the stats UI) has no business being public.

So Vör's reverse proxy (**Caddy**) has to **split one Plausible app (`:8000`) across two trust zones**:

| Path | Exposure | Why |
|---|---|---|
| `/js/*` (the tracking script) | **Public** (`0.0.0.0/0`, ports 80/443, TLS) | Every visitor's browser fetches it |
| `/api/event` (event ingestion) | **Public** | Every visitor's browser posts to it |
| `/` , `/login`, `/settings`, dashboards, everything else | **Tailscale-only** | Admin surface — bind to the tailnet interface, never the public one |
| Postgres `:5432`, ClickHouse `:8123/:9000` | **Never exposed** — internal Docker network / localhost only | Data stores |

Getting this split right — publicly serving only the two ingestion paths while binding the dashboard to
the Tailscale interface — is **the single most important and trickiest task in this build.** The Caddy
config skeleton (`docker/plausible/Caddyfile.example`) marks the intent with heavy TODOs; realizing it
correctly (and proving the dashboard is unreachable from the public IP) is a definition-of-done item.
Document the final model in `ARCHITECTURE.md` and treat it as the security centerpiece of the repo.

---

## Vör-specific conventions

The universal floor (branch → PR → **Brett merges**, no self-merge, signed commits, AgentGate on every
PR, wire up every issue/PR) lives in the two parent files. On top of that, for this repo:

- **Branch naming:** `feat/…`, `refactor/…`, `docs/…`, `ci/…`, `chore/…`.
- **Secrets never get committed — this is an IaC repo, so the surface is real.** `.gitignore` already
  covers `*.tfvars` (except `*.tfvars.example`), `.env`, `plausible-conf.env`, `*.pem`, `*.key`,
  `.terraform/`, `*.tfstate*`, and generated inventory. **Only ever commit `*.example` files.** Verify
  `git status` before every push. A leaked `do_token`, Tailscale auth key, or `SECRET_KEY_BASE` is an
  incident — stop and flag it.
- **Scoped, reviewable PRs.** One phase/slice per PR (see the build plan). AgentGate's `diff_size` rule
  warns past ~30 files / 800 lines — that's a nudge to split, not a blocker. This repo's `.agentgate.yml`
  keeps `secrets` + `dangerous_patterns` at **error** and `scope` at **warning** (solo-dev).
- **The validation gates are the tests for IaC.** Before opening a PR: `terraform fmt -recursive`,
  `terraform validate`, `tflint`, `ansible-lint`, `yamllint .`, `shellcheck scripts/*.sh`, and
  `docker compose -f docker/plausible/docker-compose.yml config -q`. CI (`.github/workflows/ci.yml`)
  runs all of these; some jobs are legitimately yellow on the bare scaffold and go green as you
  implement — **`agentgate` is the one required gate.**

## Tech stack (this is the right stack — keep it)

| Layer | Technology |
|-------|-----------|
| Provisioning | **Terraform** (DigitalOcean provider), modular (`droplet` · `firewall` · `volume`) |
| Configuration | **Ansible** (roles + a single `site.yml` playbook) |
| Runtime | **Docker** + Docker Compose |
| Analytics app | **Plausible Community Edition** (listens `:8000`) |
| Metadata store | **PostgreSQL** (accounts, site config) |
| Events store | **ClickHouse** (the analytics events — columnar, RAM-hungry) |
| Reverse proxy / TLS | **Caddy** (automatic ACME; the public/private split lives here) |
| Access | **Tailscale** — dashboard reachable only over the tailnet |
| Cloud | **DigitalOcean** (droplet, Cloud Firewall, Block Storage volume) |

Pin every image version (Plausible, Postgres, ClickHouse, Caddy) — no `latest`. Bumps flow through
Dependabot once the stack is real. ClickHouse wants RAM; default the droplet to `s-2vcpu-4gb` and put the
Postgres + ClickHouse data dirs on a **DO Block Storage volume** so analytics data survives a droplet
rebuild.

## Design principles

1. **One `project_name` threads through everything** (mirror heimdall). Droplet `<project_name>-analytics`,
   firewall `<project_name>-analytics-firewall`, tags, and the project dir `/opt/<project_name>` all
   derive from it. Decouple the repo brand ("Vör") from the deployment prefix — a stranger sets
   `project_name = "acme"` and never sees "vor" in their resources.
2. **Multi-site from day one — adding a site changes no infrastructure.** A new tracked property is added
   *inside Plausible's own dashboard/API*, and its `<script>` tag is dropped into *that site's own repo*.
   Vör's Terraform/Ansible never change to add a site. Document this crisply in `docs/ADDING-A-SITE.md`
   (the analog of heimdall's `CUSTOMIZATION.md` extension section).
3. **Safe, generic defaults; nothing org-specific baked in.** `region = "nyc3"` is a fine default;
   `ssh_allowed_ips` must be **required with no default** (never `0.0.0.0/0`); `analytics_domain` has no
   default. Every default must be safe and generic.
4. **Data durability is a first-class concern.** Analytics history is the product — losing it is
   unacceptable. DB data lives on the block-storage volume; document a backup path (`pg_dump` + ClickHouse
   backup to DO Spaces) even if the automated job is post-1.0.
5. **Everything customizable is documented.** Every variable has a description and appears in
   `CUSTOMIZATION.md` ("deploy your own privacy-first analytics host in ~30 minutes").

---

## Repo structure (target)

```
vor/
├── README.md  ARCHITECTURE.md  CUSTOMIZATION.md  CONTRIBUTING.md
├── SECURITY.md  CHANGELOG.md  ROADMAP.md  LICENSE  CLAUDE.md
├── .agentgate.yml  .yamllint.yml  .gitignore
├── .github/
│   ├── ISSUE_TEMPLATE/{config,bug_report,feature_request,support_request}.yml
│   ├── pull_request_template.md
│   ├── dependabot.yml
│   └── workflows/{ci.yml, agentgate.yml}
├── docs/
│   ├── ABOUT.md              # plain-language overview
│   └── ADDING-A-SITE.md      # the multi-site workflow — add a tracked property
├── terraform/
│   ├── environments/example/ # root module — clone this to deploy
│   └── modules/{droplet,firewall,volume}/
├── ansible/
│   ├── playbooks/site.yml
│   ├── roles/{common,security,docker,tailscale,plausible}/
│   └── inventory/            # manual.yml.example + group_vars/all.yml (real inventory gitignored)
├── docker/plausible/         # the run-by-hand path; mirrors the Ansible-templated output
│   ├── docker-compose.yml  plausible-conf.env.example  Caddyfile.example
│   └── clickhouse/{logs.xml, ipv4-only.xml}
└── scripts/{preflight.sh, setup-tailscale.sh, deploy.sh, backup.sh}
```

## Phased build plan (each phase = one or more focused PRs, maps to a milestone)

**Phase 0 — Scaffold (this PR).** Repo born-compliant (huginn), full docs suite, `.github/` templates,
CI wired, IaC/config **stubs** with TODOs. Nothing deploys yet; the shape is right.

**Phase 1 — Terraform.** Flesh out `droplet` / `firewall` / `volume` modules and the `example`
environment. Implement the firewall port model (80/443 public, 22 restricted, no other public ports).
`terraform validate` + `fmt` + `tflint` clean.

**Phase 2 — Ansible.** Implement `common` / `security` / `docker` / `tailscale` / `plausible` roles and
`site.yml`. `ansible-lint` clean. Idempotent — a second run is a no-op.

**Phase 3 — The Plausible stack + the public/private split.** Real `docker-compose.yml` (pinned images,
DB data on the volume) and the **Caddy config that publicly serves only `/js/*` + `/api/event` while
binding the dashboard to Tailscale.** Prove the dashboard is unreachable from the public IP. This is the
crux phase.

**Phase 4 — Docs & the worked example.** Finish `CUSTOMIZATION.md` (deploy walkthrough with
`brett-buskirk.dev` as the worked example), `ARCHITECTURE.md` (final component + trust-zone map),
`docs/ADDING-A-SITE.md`, `docs/ABOUT.md`. Document every variable.

**Phase 5 — CI & hardening.** Green the full CI pipeline; wire Dependabot; add the backup path; security
review of the firewall + Caddy split.

**Phase 6 — v1.0 & go-live.** Deploy the real instance, point `analytics.brett-buskirk.dev` at it, tag
`v1.0.0`, write release notes, **flip the repo public**, then do the *Closing the loop* steps below.

## Definition of Done (v1.0)

A stranger can `git clone`, read `CUSTOMIZATION.md`, set `project_name` + a short `terraform.tfvars`
(incl. `analytics_domain` + `ssh_allowed_ips`), run `terraform apply` then `ansible-playbook site.yml`,
and reach a working Plausible instance: the **tracking script + event API are public over TLS**, the
**dashboard is reachable only over Tailscale**, analytics data persists on a volume, and **adding a
second site requires zero infra changes.** The repo has the full docs suite, labels, milestones, Linear
tracking, issue/PR templates, a green-or-intentionally-yellow CI pipeline, MIT `LICENSE`, and a
tagged `v1.0.0`. AgentGate is green on the final PR.

---

## Closing the loop (once Vör is live — from `PLAUSIBLE_REPO.md`)

1. Delete/archive the brief `~/github-repos/PLAUSIBLE_REPO.md` (it's out of version control, handed off
   by path).
2. Open a **small PR in `brett-buskirk-dev`** adding the Plausible `<script>` tag to
   `src/layouts/Layout.astro`, and **close its issue #4** ("Wire privacy-friendly analytics"). That
   script tag is *that* repo's concern, not Vör's.
3. Record the connection durably: a line in `brett-buskirk-dev`'s `CLAUDE.md` pointing at Vör as "where
   analytics for this site runs," and Vör's own `README.md` listing which sites it tracks.
4. `brett-buskirk-dev` has its own dedicated agent — coordinate the link-up through Brett.

## Decisions

**Resolved**
- **Stack** — Terraform + Ansible + Docker Compose; Plausible CE + Postgres + ClickHouse + Caddy;
  DigitalOcean; Tailscale. Don't re-platform.
- **Name** — `vor` (Vör). **License** — MIT, © 2026 Brett Buskirk.
- **Generic from day one** — no org-specific deployment; `brett-buskirk.dev` is just the first *configured*
  site.
- **Visibility** — **private during the build; flip public at go-live (Phase 6).** It's an IaC repo whose
  build touches DO tokens + Tailscale keys, so it stays private until the stack is real and reviewed.

**To confirm with Brett**
- **Analytics domain** — `analytics.brett-buskirk.dev`? (drives Caddy TLS + `BASE_URL`.)
- **Droplet size / cost** — `s-2vcpu-4gb` (~$24/mo) is the recommended floor for ClickHouse. Confirm the
  monthly cost is acceptable before the real `terraform apply` (Brett is cost-conscious about always-on
  droplets — this is the first persistent VM).
- **Backups** — ship an automated `pg_dump` + ClickHouse backup to Spaces in v1.0, or defer to post-1.0?

## Reference repos (read these for exact conventions)

- **`~/github-repos/heimdall`** — the direct structural template: Terraform modules, Ansible roles,
  Docker Compose layout, `.github/` templates, CI shape, docs suite, `.yamllint.yml`. Mirror it — but
  remember Vör's public-ingestion split is the deliberate divergence from heimdall's zero-public-surface.
- **`~/github-repos/agent-gate`** — the closest model for a *shipped, productized* infra/tooling repo
  (README voice, CHANGELOG/ROADMAP discipline, release process).
- **Upstream** — [`plausible/community-edition`](https://github.com/plausible/community-edition) for the
  canonical self-hosting compose + config, and [plausible.io/docs](https://plausible.io/docs) for the
  proxy/self-host guidance.
