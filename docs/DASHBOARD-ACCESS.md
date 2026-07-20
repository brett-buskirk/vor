# Reaching the admin dashboard (Tailscale)

Vör's dashboard is deliberately **not** public — only the tracking script and event API are. The dashboard
is reached over your **tailnet**, with a real HTTPS certificate, via **Tailscale Serve**. This page explains
the model and the one-time setup.

## The model

```
  Public internet ──▶  analytics.example.com  ──▶  Caddy :443  ──▶ /js/*, /api/event only (else 404)

  Your tailnet   ──▶  <droplet>.<tailnet>.ts.net ──▶ tailscale serve (real HTTPS)
                                                        └─▶ Caddy 127.0.0.1:8443 (plain HTTP)
                                                              └─▶ Plausible :8000  (full dashboard)
```

- **Public site** (`analytics_domain`) serves only `/js/*` + `/api/event`; everything else 404s.
- **Dashboard**: Caddy serves it as plain HTTP on `127.0.0.1:8443` (loopback only — unreachable off-host).
  `tailscale serve` terminates real HTTPS on the droplet's MagicDNS name and forwards to that loopback port.
- The dashboard is reachable **only** by devices on your tailnet — never from the public IP.

## Why this shape (and not the "obvious" alternatives)

This is the design after learning what does **not** work. Plausible's login enforces three things at once:
a **CSRF** check (request `Origin` must match), a **session cookie** (`Secure` → needs HTTPS), and a
**LiveView** origin check (wants `https`). Plausible's `BASE_URL` is the public `https` domain. Given that:

| Attempt | Result |
|---|---|
| Dashboard on plain **HTTP** over the tailnet | Login returns **403** — CSRF/cookie/LiveView can't agree over http |
| Dashboard **HTTPS on a bare tailnet IP** (`tls internal`) | Caddy's internal CA **won't issue a cert for a bare IP** → TLS `internal error`, connection dropped |
| **Tailscale Serve + a real cert + header rewrites** ✅ | Scheme, host, cert, and cookie all line up → login and LiveView work |

The Caddy dashboard block rewrites the upstream headers so Plausible sees a request that matches its
`BASE_URL` even though it arrived over the tailnet:

```
header_up Host {$ANALYTICS_DOMAIN}
header_up X-Forwarded-Proto https
header_up Origin https://{$ANALYTICS_DOMAIN}
```

## One-time setup

**1. Enable HTTPS certificates for your tailnet** (once per tailnet): Tailscale admin console → **DNS** →
enable **MagicDNS** and **HTTPS Certificates**.

**2. Front the dashboard with Tailscale Serve** (on the droplet). The Ansible `plausible` role does this for
you; to do it by hand (or to re-apply):

```bash
tailscale serve --bg --https=443 http://127.0.0.1:8443
tailscale serve status      # prints your dashboard URL
```

`serve status` shows the URL, e.g. `https://vor-analytics.<your-tailnet>.ts.net/`.

**3. Browse it** from any device on the tailnet:

```
https://<droplet>.<your-tailnet>.ts.net/
```

Real cert, green padlock, no warning — and login works.

## Accessing it day to day

- **Any tailnet device** (laptop, phone with the Tailscale app) can reach the URL. Bookmark it.
- **A full-tunnel VPN (e.g. NordVPN) will break this** — it captures the `100.64.0.0/10` CGNAT range
  Tailscale uses and routes it away from the tailnet. Turn the VPN off (or split-tunnel the tailnet range)
  when reaching the dashboard **or** SSHing to the droplet over Tailscale.
- **SSH** works the same way: `ssh root@<droplet>.<your-tailnet>.ts.net` (or the Tailscale IP), no public
  SSH needed. Dropping public `:22` entirely is a good hardening follow-up (R5 in
  [SECURITY-REVIEW.md](SECURITY-REVIEW.md)).

## Turning it off / changing it

```bash
tailscale serve --https=443 off      # stop serving the dashboard over the tailnet
tailscale serve status               # inspect current mappings
```
