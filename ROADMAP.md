# Roadmap

_What's planned for Vör — a phased build from scaffold to a live, public v1.0. Each phase is one or more
focused PRs and maps to a milestone. Check items off as they ship._

## Phase 0 — Scaffold ✅ (this repo)
- [x] Born-compliant repo (huginn): license, ruleset, labels, `.agentgate.yml`, CI.
- [x] Full docs suite (README, ARCHITECTURE, CUSTOMIZATION, SECURITY, CONTRIBUTING, CLAUDE, ABOUT,
      ADDING-A-SITE).
- [x] `.github/` templates (issues, PR, dependabot) and the CI pipeline.
- [x] Terraform / Ansible / Docker / scripts **stubs** with `TODO(vor)` markers.

## Phase 1 — Terraform ✅
- [x] Flesh out `droplet`, `firewall`, and `volume` modules and the `environments/example` root.
- [x] Implement the firewall port model (80/443 public, 22 restricted, nothing else).
- [x] `terraform validate` + `fmt` + `tflint` clean.

## Phase 2 — Ansible ✅
- [x] Implement `common`, `security`, `docker`, `tailscale`, `plausible` roles and `site.yml`.
- [x] Idempotent (second run is a no-op); `ansible-lint` clean.

## Phase 3 — Plausible stack + the public/private split ✅
- [x] Real `docker-compose.yml` (pinned images; all state on the volume).
- [x] The Caddy config that publicly serves **only** `/js/*` + `/api/event` and binds the dashboard to
      Tailscale. Validated with `caddy validate`.
- [ ] Prove the dashboard is unreachable from the public IP — a runtime check that lands with the live
      deploy (Phase 6).

## Phase 4 — Docs & worked example
- [x] Finish `CUSTOMIZATION.md` with `brett-buskirk.dev` as the worked example.
- [x] Final `ARCHITECTURE.md` component + trust-zone map; document every variable.

## Phase 5 — CI & hardening
- [ ] Green the full CI pipeline; wire Dependabot.
- [ ] Backup path (`pg_dump` + ClickHouse → Spaces).
- [ ] Security review of the firewall + Caddy split.

## Phase 6 — v1.0 & go-live
- [ ] Deploy the real instance; point `analytics.brett-buskirk.dev` at it.
- [ ] Tag `v1.0.0`; write release notes; **flip the repo public**.
- [ ] *Closing the loop*: add the `<script>` tag to `brett-buskirk-dev` (`Layout.astro`), close its
      issue #4, and link the two repos.

## Post-1.0 ideas
- [ ] Automated, scheduled backups with retention.
- [ ] Remote Terraform state (Spaces/S3 backend).
- [ ] Optional second cloud provider / staging environment.
- [ ] Uptime/health alerting for the analytics host itself.
