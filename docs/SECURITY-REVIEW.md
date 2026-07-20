# Security review — firewall & the public/private split

**Scope:** the network perimeter of a Vör deployment — the DigitalOcean Cloud Firewall, the Caddy
public/private split, data-store isolation, host hardening, and secrets handling.
**Method:** design + code review of the Terraform firewall module, the Ansible `security`/`tailscale`
roles, and the Caddy + Compose configuration, against the stated goal: *only* the two ingestion paths are
public; everything else is private.
**Date:** 2026-07-18. **Reviewer:** build agent, for Brett Buskirk (human sign-off pending the live deploy).

This is a design review of the code as shipped. The runtime proofs in [§6](#6-verification) are executed
against the live instance at go-live (Phase 6) and are a definition-of-done gate.

---

## 1. Assets

| Asset | Sensitivity | Where |
|---|---|---|
| Visitor analytics history | High — irreplaceable, the product | ClickHouse, on the data volume |
| Accounts, site config, API keys | High | PostgreSQL, on the data volume |
| Admin session / dashboard access | High | Plausible, reached over Tailscale |
| Secrets (`SECRET_KEY_BASE`, DB pw, DO/Tailscale keys) | High | env files (0600), runtime vars |
| The droplet itself (compute) | Medium | DigitalOcean |

## 2. Trust zones

1. **Public internet** — untrusted. May reach only `:80`/`:443` on the droplet's public IP.
2. **Tailnet** — authenticated mesh. Reaches the admin dashboard.
3. **Host / internal Docker network** — the databases; never crosses zones 1 or 2.

The whole design is the boundary between zone 1 and zones 2–3: ingestion is unavoidably public, everything
else is not.

## 3. Attack surface

| Entry point | Exposure | Control |
|---|---|---|
| `:443` `/js/*`, `/api/event` | Public | Caddy serves only these two path groups; all else 404s |
| `:80` | Public | ACME challenge + redirect to `:443` only |
| dashboard (`:8443` internally) | Tailnet only | Published on `127.0.0.1` only; Tailscale Serve fronts it over the tailnet |
| `:22` SSH | `ssh_allowed_ips` only | Cloud Firewall allow-list; key-only auth; fail2ban |
| Postgres `:5432`, ClickHouse `:8123/:9000` | None | No published ports; internal Docker network only |

## 4. Control review

### 4.1 Cloud Firewall (Terraform `firewall` module)
Default-deny inbound. Only `80`/`443` from `0.0.0.0/0` (+ IPv6) and `22` from `var.ssh_allowed_ips`, which
is **required with no default** and validated non-empty. The database ports are simply absent, so they are
denied. The firewall is enforced by DigitalOcean at the network edge, *outside* the droplet — so the
well-known "Docker publishes past the host firewall" footgun does **not** apply to it: Docker cannot punch
through the Cloud Firewall. **Assessment: sound.**

### 4.2 The Caddy public/private split
Enforced in **two independent layers**, either of which alone would keep the dashboard private:

1. **Path rules (Caddy).** The public site (`{$ANALYTICS_DOMAIN}`) matches only `/js/*` and `/api/event`
   and returns `404` for everything else. The dashboard lives on a separate `:8443` listener.
2. **Loopback binding + Tailscale Serve (Compose).** The public listener is published on the droplet's
   **public IP**; the `:8443` dashboard listener is published **only on `127.0.0.1`**, so it is not
   reachable off-host at all. Tailscale Serve terminates HTTPS on the tailnet and forwards to that loopback
   port — so the dashboard is reachable only by tailnet devices, and even a Caddyfile mistake in layer 1
   could not expose it publicly (nothing binds it to the public interface). See `docs/DASHBOARD-ACCESS.md`.

The Caddyfile is validated in CI (`caddy validate`), so a broken split fails the build. **Assessment:
sound; defense in depth.** Residual: the dashboard's exposure now depends on the Tailscale Serve config and
a well-governed tailnet (see R2) — mitigated by the runtime proof in §6.

### 4.3 Data-store isolation
Postgres and ClickHouse declare no `ports:` — they are reachable only on the internal `vor` Docker network
by service name. They never bind to the public or Tailscale interface. **Assessment: sound.**

### 4.4 Host hardening (`brett-buskirk.baseline` + `secure_user`, + vor's `common`)
The host baseline is the published `brett-buskirk.baseline` role and its `secure_user` dependency: a
passwordless-sudo user with key-only SSH, SSH password auth disabled, `fail2ban` on SSH, Docker + Compose
and Tailscale from their official apt repos, and UFW (default-deny inbound; `80`/`443` + SSH) as
defense-in-depth. vor's `common` role adds `unattended-upgrades`. vor keeps root SSH (key-only) for now;
dropping it is the R5 follow-up. **Assessment: solid baseline — reused, not reinvented.**

### 4.5 Secrets handling
Only `*.example` files are tracked; real `*.tfvars`, `plausible-conf.env`, keys, and the rendered Caddyfile
are gitignored. GitGuardian scans every PR. The Tailscale auth key is passed at runtime, never committed.
Env files are mode `0600`. **Assessment: sound;** see R3 below for a least-privilege nuance.

## 5. Residual risks

| # | Risk | Severity | Disposition |
|---|---|---|---|
| **R1** | The public `/api/event` endpoint has no rate limiting — open to event spam / volumetric abuse. | Medium | **Mitigation planned.** Add Caddy `rate_limit` on the public site, and/or front with a CDN. Plausible does some server-side handling, but this is the most exposed surface. |
| **R2** | The tailnet is a flat trust zone — the dashboard is published on the tailnet interface, so **any** device on the tailnet can reach it. | Medium | **Recommendation:** apply **Tailscale ACLs** (tag the droplet, restrict which users/devices may reach it). The security model assumes a well-governed tailnet; ACLs make that explicit. |
| **R3** | The shared `plausible-conf.env` is injected into the Postgres container too, so Postgres sees app-only secrets (`SECRET_KEY_BASE`, SMTP creds). | Low | **Accepted** for a single-tenant, root-controlled host. A dedicated Postgres env file would tighten least-privilege if ever multi-tenant. |
| **R4** | Single Docker network — a compromised Plausible (or Caddy) container can reach Postgres/ClickHouse directly. | Medium | **Accepted** for single-node Compose. Future hardening: split networks so only Plausible shares the DB network (Caddy needs only Plausible). |
| **R5** | Two standing admin paths: SSH on `:22` *and* Tailscale SSH (`--ssh`). | Low | **Recommendation:** after provisioning, consider dropping public `:22` from the firewall and administering solely over Tailscale SSH, shrinking the public surface to `80`/`443` only. |
| **R6** | No dedicated WAF / L7 DDoS protection beyond DigitalOcean's platform + Caddy. | Low–Medium | **Accepted** for a personal/small-team host; revisit with a CDN/WAF if traffic or threat warrants (pairs with R1). |

None of the residual risks expose the dashboard or the databases to the public internet; they are
abuse-resistance and depth-of-defense refinements. R1 and R2 are the two worth acting on before a
high-visibility launch.

## 6. Verification

These runtime proofs are a definition-of-done gate, executed against the live instance at go-live.
From a host **not** on the tailnet, against the droplet's public IP:

```bash
PUB=<droplet-public-ip>; DOMAIN=<analytics_domain>
curl -sS -o /dev/null -w "js:%{http_code}\n"    "https://${DOMAIN}/js/script.js"   # expect 200
curl -sS -o /dev/null -w "event:%{http_code}\n" -X POST "https://${DOMAIN}/api/event"  # expect 202/400, not 404
curl -skS -o /dev/null -w "login:%{http_code}\n" "https://${PUB}/login"            # expect 404 (never 200)
nc -z -w3 "${PUB}" 5432 && echo "PG OPEN (BAD)" || echo "pg: refused (good)"
nc -z -w3 "${PUB}" 8123 && echo "CH OPEN (BAD)" || echo "ch: refused (good)"
```

From a host **on** the tailnet: the dashboard at the droplet's Tailscale address loads and `/login` works.

**Pass criteria:** public IP serves the two ingestion paths and 404s the dashboard; database ports refuse;
the dashboard answers only over the tailnet. Record the output in the v1.0 release notes.

## 7. Conclusion

The perimeter design meets its goal: the only public surface is the two ingestion paths over TLS, enforced
by two independent layers; the dashboard is Tailscale-only; the databases are unreachable off the internal
network; and the firewall is default-deny with SSH restricted. The residual risks are abuse-resistance
refinements (R1, R2 worth acting on), not exposure of sensitive assets. **Recommendation: proceed to the
live deploy, execute the §6 proofs as a go-live gate, and track R1/R2 as fast-follow hardening.**
