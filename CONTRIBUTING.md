# Contributing

Vör is part of [Brett Buskirk](https://github.com/brett-buskirk)'s estate. The universal rules (branch →
PR → **Brett merges**, signed commits, no direct commits to `main`) apply here as everywhere.

## Workflow

- **No direct commits to `main`.** Branch → open a PR with the `gh` CLI → let checks run → Brett merges.
  Never self-merge.
- **Branch naming:** `feat/…`, `refactor/…`, `docs/…`, `ci/…`, `chore/…`.
- **Scoped PRs.** One phase/slice per PR (see [ROADMAP.md](ROADMAP.md)). Prefer a stack of focused PRs over
  one large diff — AgentGate warns past ~30 files / 800 lines.
- **Signed commits**, ending with the `Co-Authored-By:` trailer for agent-authored work.

## Never commit secrets

This is an IaC repo — the secret surface is real. `*.tfvars`, `.env`, `plausible-conf.env`, `*.pem`,
`*.key`, Tailscale auth keys, and generated inventory are gitignored. **Only ever commit `*.example`
files.** Run `git status` before every push.

## Validation gates (the "tests" for IaC)

Run these locally before opening a PR — CI (`.github/workflows/ci.yml`) runs the same:

```bash
terraform fmt -recursive terraform/
terraform -chdir=terraform/environments/example validate
tflint --chdir=terraform/environments/example
ansible-galaxy install -r ansible/requirements.yml   # roles + collections (needed for ansible-lint)
ansible-lint ansible/
yamllint .
shellcheck scripts/*.sh
docker compose -f docker/plausible/docker-compose.yml config -q
```

CI runs these plus `tfsec` (advisory) and `caddy validate` (the reverse-proxy config). CI is green on
`main`; keep it that way. **`agentgate` is the required check.**

## How to...

- **Add a Terraform variable** — declare it in the module's `variables.tf` with a `description` and
  `type`, thread it through `environments/example`, and add it to `terraform.tfvars.example` and the
  `CUSTOMIZATION.md` variable reference.
- **Add an Ansible task** — put it in the right role; keep it idempotent (a second playbook run is a
  no-op).
- **Change the public/private split** — that lives in Caddy (`docker/plausible/Caddyfile.example`). Treat
  it as security-critical and explain the change in the PR.
