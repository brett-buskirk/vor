## What & why

<!-- Describe the change and link the issue it resolves -->

Closes #

## Type of change

- [ ] Terraform
- [ ] Ansible
- [ ] Docker / Plausible stack
- [ ] Caddy / networking
- [ ] Documentation
- [ ] CI / validation
- [ ] Chore / refactor

## Checklist

- [ ] `terraform fmt -check -recursive` passes
- [ ] `terraform validate` passes (per changed environment/module)
- [ ] `ansible-lint` passes
- [ ] `yamllint` passes
- [ ] `shellcheck` passes (if `.sh` files changed)
- [ ] `docker compose -f docker/plausible/docker-compose.yml config -q` passes (if the stack changed)
- [ ] No secrets committed — only `*.example` files
- [ ] Docs updated if behavior or variables changed
