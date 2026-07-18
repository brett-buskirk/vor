# Changelog

All notable changes to Vör are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial scaffold for a self-hosted, privacy-first [Plausible](https://plausible.io) analytics stack on
  DigitalOcean (Terraform + Ansible + Docker Compose + Tailscale).
- Full documentation suite: README, ARCHITECTURE, CUSTOMIZATION, SECURITY, CONTRIBUTING, CLAUDE build
  brief, plus `docs/ABOUT.md` and `docs/ADDING-A-SITE.md`.
- `.github/` templates (issue forms, PR template, Dependabot) and a CI pipeline
  (terraform fmt/validate/tflint, tfsec, ansible-lint, yamllint, shellcheck, docker compose config).
- Terraform (`droplet` / `firewall` / `volume` modules + `example` environment), Ansible
  (`common` / `security` / `docker` / `tailscale` / `plausible` roles), Docker Compose, and helper
  script **stubs** with `TODO(vor)` markers — the shape of the stack ahead of implementation.

_This project is greenfield and generic from day one: it is designed to track multiple sites from a single
instance, with `brett-buskirk.dev` as the first configured property._
