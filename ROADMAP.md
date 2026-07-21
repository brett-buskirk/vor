# Roadmap

_Vör's phased build, from scaffold to a live v1.0. Each phase was one or more focused PRs mapping to a
milestone. Phases 0–6 shipped; the instance is deployed and tracking traffic. Below the line are post-1.0
ideas._

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
- [x] Implement the `common` + `plausible` roles and `site.yml`, building on the published
      `brett-buskirk.baseline` role (+ its `secure_user` dependency) for host hardening.
- [x] Idempotent (second run is a no-op); `ansible-lint` clean.

## Phase 3 — Plausible stack + the public/private split ✅
- [x] Real `docker-compose.yml` (pinned images; data on the block-storage volume).
- [x] The Caddy config that publicly serves **only** `/js/*` + `/api/event` while the dashboard rides
      Tailscale (`tailscale serve` + real HTTPS). Validated with `caddy validate`.
- [x] Prove the dashboard is unreachable from the public IP — verified at the live deploy (public IP 404s
      the dashboard; it answers only over the tailnet).

## Phase 4 — Docs & worked example ✅
- [x] Finish `CUSTOMIZATION.md` with `brett-buskirk.dev` as the worked example.
- [x] Final `ARCHITECTURE.md` component + trust-zone map; document every variable.

## Phase 5 — CI & hardening ✅
- [x] Green the full CI pipeline; wire Dependabot — added the `docker` ecosystem, pinned the shellcheck
      action, and added a `caddy validate` job.
- [x] Backup path — `scripts/backup.sh` (pg_dump + ClickHouse logical dumps) + [docs/BACKUP.md](docs/BACKUP.md).
      Automated scheduling to Spaces is post-1.0.
- [x] Security review of the firewall + Caddy split — [docs/SECURITY-REVIEW.md](docs/SECURITY-REVIEW.md).

## Phase 6 — v1.0 & go-live ✅
- [x] Deploy the real instance; point `analytics.brett-buskirk.dev` at it.
- [x] Tag `v1.0.0` and write release notes.
- [x] *Closing the loop*: `<script>` tag added to `brett-buskirk-dev` (`Layout.astro`), its issue #4
      closed, and the tracked site listed in the README.
- [ ] Flip the repo public (enable secret scanning + push protection first).

## Post-1.0 ideas
- [ ] Automated, scheduled backups with retention (to a DO Spaces bucket).
- [ ] Remote Terraform state (DO Spaces `s3` backend) — can share the backups bucket; setup documented
      in [CUSTOMIZATION.md](CUSTOMIZATION.md).
- [ ] Optional second cloud provider / staging environment.
- [ ] Uptime/health alerting for the analytics host itself.
