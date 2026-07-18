# Backup & restore

Vör's analytics history *is* the product, so losing it is the one truly bad outcome. This is the backup
and restore playbook. There are two complementary layers — use both.

## What needs backing up

Everything stateful lives on the attached **Block Storage volume** at `/mnt/<project_name>-analytics-data`:

| Data | Store | Why it matters |
|---|---|---|
| Accounts, site config, API keys | PostgreSQL (`plausible_db`) | Losing it means re-creating every site and user |
| The analytics events | ClickHouse (`plausible_events_db`) | The actual history — irreplaceable |
| Plausible app state, Caddy certs | on the volume | Convenient to keep, but regenerable |

Because it's all on one volume, a single **volume snapshot** captures a consistent-enough copy of the
whole thing — that's the cheapest safety net. Logical dumps add portability and table-level restore.

---

## Layer 1 — Volume snapshots (primary DR, cheapest)

A DigitalOcean Block Storage snapshot of the data volume captures Postgres **and** ClickHouse in one
operation. It's the fastest path back after a bad upgrade, an accidental `terraform destroy`, or a
corrupt droplet.

```bash
# Find the volume id (or read it from: terraform output volume_id)
doctl compute volume list

# Take a snapshot
doctl compute volume snapshot <volume-id> \
  --snapshot-name "vor-$(date -u +%Y%m%dT%H%M%SZ)"
```

Do this before every image upgrade and on a schedule you're comfortable with (DO can also take
scheduled, retained snapshots from the control panel). Snapshots are billed by size; prune old ones.

**Restore from a snapshot:** create a new volume *from* the snapshot, attach it to the droplet, and mount
it at the data root — then bring the stack up.

```bash
# 1. Create a volume from the snapshot (same region as the droplet)
doctl compute volume create <project_name>-analytics-data \
  --region <region> --snapshot <snapshot-id>

# 2. Attach it, then on the droplet remount and start:
#    (detach the old volume first if you're replacing it)
mount /dev/disk/by-id/scsi-0DO_Volume_<project_name>-analytics-data \
  /mnt/<project_name>-analytics-data
cd /opt/<project_name> && docker compose up -d
```

Re-running `ansible-playbook site.yml` after attaching the restored volume does the mount + start for you
(the `filesystem` task never reformats a volume that already holds data).

---

## Layer 2 — Logical dumps (portability & table-level restore)

`scripts/backup.sh` runs on the droplet and writes a timestamped set of dumps to
`/var/backups/<project_name>/<timestamp>/`:

- `postgres-plausible_db.sql.gz` — a full `pg_dump`.
- `clickhouse-<table>.schema.sql` + `clickhouse-<table>.native.gz` — each events table's `CREATE`
  statement plus its rows in ClickHouse Native format.

```bash
# On the droplet:
./scripts/backup.sh

# With an offsite copy to DO Spaces (credentials from the environment / aws config):
SPACES_BUCKET=my-vor-backups ./scripts/backup.sh
```

Logical dumps survive things a snapshot can't help with — moving to a new region or provider, restoring a
single table, or reading the data outside ClickHouse.

### Restore from logical dumps

**PostgreSQL:**

```bash
gunzip -c postgres-plausible_db.sql.gz \
  | docker compose exec -T plausible_db psql -U postgres -d plausible_db
```

**ClickHouse** — recreate each table from its schema file, then stream the rows back:

```bash
# schema (once per table)
docker compose exec -T plausible_events_db clickhouse-client \
  --query "$(cat clickhouse-events_v2.schema.sql)"

# data
gunzip -c clickhouse-events_v2.native.gz \
  | docker compose exec -T plausible_events_db clickhouse-client \
      --query "INSERT INTO plausible_events_db.events_v2 FORMAT Native"
```

Restore into a **freshly migrated, empty** instance (let Plausible create the databases/schema first via
its normal startup), then load Postgres before ClickHouse so site config exists for the events.

---

## Post-1.0 automation

v1.0 ships the manual path above. The scheduled/automated story is deliberately deferred:

- A **systemd timer** (or cron entry) running `backup.sh` nightly.
- **Retention** — keep N daily / M weekly locally and in Spaces; prune the rest.
- **Failure alerting** — notify if a run errors or hasn't succeeded in 24h.
- **Scheduled volume snapshots** with retention, via the DO API.

These land as a follow-up so v1.0 keeps a tight, reviewable surface — the durability guarantee (data on a
snapshottable volume + a working dump script) is already in place.
