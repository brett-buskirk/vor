# About Vör — the plain-language version

**Vör is a way to see how many people visit your website, without spying on them.**

Most websites use Google Analytics to count visitors. It works, but it comes with baggage: it loads a
heavy chunk of code onto your page, it tracks people with cookies, it usually means you need one of those
annoying "we use cookies" consent pop-ups, and it hands your visitors' data to an advertising company.

Vör runs [**Plausible**](https://plausible.io) instead — an open-source analytics tool that is:

- **Lightweight** — its tracking code is tiny, so your pages stay fast.
- **Cookieless** — it doesn't follow people around with cookies, so in most places you don't need a
  consent banner.
- **Private** — it doesn't collect personal information about your visitors.

The twist is that Vör runs Plausible **on your own server**, not someone else's. Your visitor data lives
on a machine you control and never gets sold or shared.

## What's in the box

Vör is a set of instructions (as code) that:

1. Rents a small server from DigitalOcean and sets up its firewall.
2. Installs the analytics software (Plausible) and the two databases it needs.
3. Wires up the security so that the **public** only ever touches the tiny tracking script and the
   endpoint that receives pageviews — and **the admin dashboard, where you read your stats, is locked
   behind a private network** ([Tailscale](https://tailscale.com/)) that only your own devices can reach.

Because it's all written as code, anyone can copy it, change a few settings, and stand up their own
private analytics in about half an hour — no clicking around a control panel, and it's reproducible.

## One server, many websites

You don't need a separate setup for each site you own. One Vör instance can count visitors for several
websites at once. Adding a new one is just a couple of clicks in the dashboard plus pasting one line of
code into that website — no server changes at all.

## Who it's for

Anyone who wants honest visitor numbers without the privacy tradeoffs of the big analytics services —
and who'd rather own their data than rent it. For Brett, it's both a tool he actually uses and an example
of the privacy-first infrastructure he builds for clients.

For the technical details, see the [README](../README.md) and [ARCHITECTURE.md](../ARCHITECTURE.md).
