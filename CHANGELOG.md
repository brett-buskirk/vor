# Changelog

All notable changes to Vör are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_Nothing yet._

## [1.0.0] - 2026-07-21

First public release — a complete, deployed, self-hosted privacy-first analytics stack. A stranger can
clone the repo, set a handful of variables, and stand up their own [Plausible](https://plausible.io)
instance in ~30 minutes. Verified against a live production deployment.

### Added
- **Provisioning (Terraform).** Modular `droplet` / `firewall` / `volume` modules and an `example`
  environment. Firewall model: `80`/`443` public for ingestion + ACME, `22` restricted to `ssh_allowed_ips`
  (required, no default), nothing else. Optional DO Spaces `s3` remote-state backend (documented).
- **Configuration (Ansible).** A `site.yml` playbook running `common` → `brett-buskirk.baseline` →
  `plausible`. Host hardening (a non-root sudo user, key-only SSH, fail2ban, UFW, Docker + Compose, and
  Tailscale) comes from the published `brett-buskirk.baseline` role and its `secure_user` dependency; the
  `common` role mounts the block-storage volume and the `plausible` role renders and launches the stack
  and exposes the dashboard via Tailscale Serve.
- **The stack (Docker Compose).** Plausible CE `v3.2.1`, `postgres:16-alpine`,
  `clickhouse/clickhouse-server:24.12-alpine`, `caddy:2-alpine` — all pinned, tracked by Dependabot.
  ClickHouse tuned for the `s-2vcpu-4gb` default node.
- **The public/private split (Caddy).** Only the tracking script (`/js/*`) and event API (`/api/event`)
  are public, over a real Let's Encrypt cert. The admin dashboard is served over the tailnet only —
  Caddy on `127.0.0.1:8443` fronted by `tailscale serve` with a real HTTPS cert on the droplet's MagicDNS
  name, plus header rewrites so Plausible login/LiveView work. See `docs/DASHBOARD-ACCESS.md`.
- **Data durability.** PostgreSQL, ClickHouse, and Caddy's certs live on an attached DO Block Storage
  volume, so the droplet can be rebuilt with zero data loss. Backup path: volume snapshots (primary DR)
  plus `scripts/backup.sh` (`pg_dump` + ClickHouse dumps, optional upload to Spaces) — see `docs/BACKUP.md`.
- **Multi-site from day one.** Additional tracked sites are added in the Plausible dashboard with a script
  tag in that site's own repo — no infrastructure change (`docs/ADDING-A-SITE.md`).
- **Documentation.** README, ARCHITECTURE, CUSTOMIZATION (deploy walkthrough), SECURITY + a written
  SECURITY-REVIEW (threat model of the firewall + split), DASHBOARD-ACCESS, BACKUP, ABOUT, ADDING-A-SITE,
  and CONTRIBUTING.
- **CI / governance.** `.github/` templates, Dependabot (terraform · github-actions · docker), and a CI
  pipeline: terraform fmt/validate/tflint, tfsec, ansible-lint, yamllint, shellcheck, `docker compose
  config`, `caddy validate`, and AgentGate.

_Greenfield and generic from day one: designed to track multiple sites from a single instance, with
`brett-buskirk.dev` as the first configured property._

[Unreleased]: https://github.com/brett-buskirk/vor/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/brett-buskirk/vor/releases/tag/v1.0.0
