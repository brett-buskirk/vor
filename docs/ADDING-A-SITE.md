# Adding a tracked site

One of Vör's core design goals: **adding a new site to track requires no infrastructure change.** You
don't run Terraform, you don't touch Ansible, you don't redeploy anything. A new property is added inside
Plausible's own dashboard, and its tracking snippet goes into *that site's* own repository.

This is what makes one Vör instance a multi-site analytics host rather than a one-site appliance.

> Prerequisite: a live Vör instance with its dashboard reachable over Tailscale, and its analytics domain
> (e.g. `analytics.example.com`) serving the tracking script publicly over TLS. If you're standing the
> instance up for the first time, see [CUSTOMIZATION.md](../CUSTOMIZATION.md).

## Steps

### 1. Add the site in the Plausible dashboard

1. Connect your device to the tailnet and open the Vör dashboard (its Tailscale hostname).
2. Click **+ Add website**.
3. Enter the site's domain exactly as it will appear in the snippet — e.g. `helm.brett-buskirk.dev`. This
   `data-domain` value is how Plausible separates one site's stats from another's; they all share the one
   instance.
4. Choose the timezone and any optional features (outbound-link clicks, custom events, etc.).

### 2. Drop the snippet into that site's repo

Plausible shows a `<script>` snippet. Add it to the `<head>` of that site — **in that site's own
repository**, as a small PR. The `src` points at *your Vör instance's* analytics domain, not at
`plausible.io`:

```html
<script defer
        data-domain="helm.brett-buskirk.dev"
        src="https://analytics.brett-buskirk.dev/js/script.js"></script>
```

- `data-domain` — the site you added in step 1 (each tracked site uses its own value).
- `src` — always your Vör instance's public analytics domain. This is the `/js/*` path Caddy serves
  publicly; the file is the sub-1 KB tracker.

For different feature sets, Plausible offers script variants (e.g. `script.outbound-links.js`,
`script.tagged-events.js`) — copy whichever the dashboard shows for the options you picked; the `src` host
stays the same.

### 3. Verify

Deploy the site change, visit the page, and confirm the visit appears in the Vör dashboard within a few
seconds. Plausible's dashboard has a "verify your installation" check that confirms the snippet is
loading and events are arriving.

## Why no infrastructure change?

The event API (`/api/event`) and the tracking script (`/js/*`) are already public on the Vör instance —
they don't care how many sites use them. PostgreSQL records the new site's configuration (added via the
dashboard in step 1); ClickHouse records its events, partitioned by `data-domain`. Nothing about the
droplet, firewall, or Docker stack needs to change to add the hundredth site.

## Estate note

For Brett's estate specifically: the `<script>` tag for `brett-buskirk.dev` is added in the
**`brett-buskirk-dev`** repo (its `src/layouts/Layout.astro`), which closes that repo's issue #4. That
repo has its own dedicated agent — coordinate the change through Brett rather than reaching into it from
here. Keep Vör's `README.md` updated with the list of sites this instance tracks.
