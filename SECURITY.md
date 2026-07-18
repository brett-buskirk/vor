# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.x     | Yes       |

## Reporting a Vulnerability

Please do **not** file a public GitHub issue for security vulnerabilities.

Report them privately via [GitHub's private vulnerability reporting](https://github.com/brett-buskirk/vor/security/advisories/new).

Include:
- A description of the vulnerability
- Steps to reproduce
- Potential impact

You'll receive a response within 48 hours. Valid reports will be credited in the release notes unless you
prefer anonymity.

## Scope

Vör is an Infrastructure-as-Code template for a self-hosted analytics host. Key security considerations:

- **No secrets committed.** Only `*.example` files are tracked. Real credentials — `*.tfvars`, `.env`,
  `plausible-conf.env`, `*.pem`, `*.key`, Tailscale auth keys, generated inventory — are gitignored.
- **Minimal public surface.** Only the tracking script (`/js/*`) and event API (`/api/event`) are exposed
  to the public internet, over TLS. The admin dashboard, login, and settings are bound to the **Tailscale**
  interface and are not reachable from the droplet's public IP.
- **Data stores are never public.** PostgreSQL and ClickHouse bind only to the internal Docker network.
- **Cloud Firewall defaults to deny.** Inbound is limited to `80`/`443` (public ingestion + ACME) and `22`
  from explicitly specified IPs (`ssh_allowed_ips`, required — no `0.0.0.0/0` default). Tailscale needs no
  inbound holes.
- **Privacy by design.** Plausible is cookieless and collects no personal data; self-hosting keeps
  visitor data on infrastructure you control.
- **Image versions are pinned.** Docker image tags are explicit; Dependabot monitors for updates.
