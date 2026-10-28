# 03 — Operations

## Backups and restore

| What | How | Retention |
|---|---|---|
| ERP + mobile databases | RDS automated backups + point-in-time restore | 7 days |
| Before risky changes | Manual RDS snapshot / AMI | Until the change is accepted |
| ERP database (off-site) | Logical replica at the DR site + nightly `pg_dump` there | Replica = live; dumps 14 days |
| ERP filestore + modules | Daily rsync to the DR site | Latest copy |
| Decommissioned systems | Final RDS snapshot + AMI before shutdown | Until the business signs off |

**Restore drills:**
- Production databases are copied into test environments with scripted `pg_dump -Fc` → `pg_restore` jobs.
- This exercises the restore path regularly, not only during an incident.

## Environment refresh (prod → test)

A Bash script runs the refresh:
1. Dumps the production database in custom format.
2. Copies the dump to the test server.
3. Drops and recreates the test database.
4. Restores it with parallel `pg_restore` jobs.

## Patching

- **OS:** Ubuntu LTS. New servers are built on the current LTS (24.04). Reboots happen in a maintenance window.
- **RDS:** minor versions auto-upgrade in the maintenance window. For the Odoo 14 → 18 migration, a new PostgreSQL 17 instance was built, and the old one was kept as a final snapshot.
- **TLS:** Certbot renews certificates automatically. Certificate files are backed up off-host.

## Monitoring

- **Performance Insights** on both databases, for top SQL and wait events.
- RDS PostgreSQL logs in **CloudWatch Logs**: slow queries, connection errors, replication messages.
- **DR replication status script:**
  - reports subscription state, per-table sync state and slot lag;
  - verifies row counts and row hashes table by table after the first copy.

## Cost

- Monthly spend by service is reviewed in **Cost Explorer**. Databases are the largest line, as expected for two always-on RDS instances.
- Levers already used: **Graviton** instances for the ERP app and both databases, **gp3** storage, and right-sized instance classes.
- Levers on the roadmap: Savings Plans / Reserved Instances for the steady-state instances, and log-retention policies.

## Runbooks

These exist as written procedures, mostly in the [DR repo](https://github.com/altaheri86/odoo-pg-logical-dr):
- DR failover;
- Odoo module upgrade (with replication);
- prod → test refresh;
- password rotation;
- certificate renewal;
- server rebuild.
