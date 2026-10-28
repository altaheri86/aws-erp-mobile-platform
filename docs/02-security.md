# 02 — Security

Security is layered from the network edge down to the data.

| Layer | Control in place |
|---|---|
| **Transport** | HTTPS only for users (Let's Encrypt, auto-renewed). RDS enforces TLS for every client (`rds.force_ssl=1`). The DR replication link uses TLS (`sslmode=require`). |
| **Network** | Security groups per workload. PostgreSQL ports accept connections only from their app server and one allow-listed office IP. Odoo listens on localhost behind Nginx. Databases are in their own subnet group. |
| **Data at rest** | RDS storage encrypted with KMS. S3 server-side encryption. Encrypted automated backups and snapshots. |
| **Identity** | Named IAM users per engineer, MFA on admin accounts, root MFA, no root access keys. Read-only audits use the IAM credential report (key age, last use, MFA). |
| **Instance** | IMDSv2 required on the ERP host. SSH by key pair. |
| **Database** | A separate RDS instance per system. The replication user has `SELECT` + `rds_replication` only. Deletion protection on both instances. |
| **Secrets** | Kept out of code and repos. Database passwords live in `.pgpass` files (mode 600) on the servers and in the team's password manager. |
| **Change hygiene** | Snapshot before major changes. Changes go through a written runbook and a dated work log. |

## Practices worth calling out

- **Least privilege for replication.** The DR subscriber logs in as a dedicated role with read-only grants and `statement_timeout = 0`, set on that role only. The application roles keep their protective timeout.
- **Outbound-only DR.** The office server always initiates the connection to RDS, so no inbound port is opened on the office firewall. The RDS side allow-lists the office's *egress* IP, which is not the same as its inbound NAT IP.
- **Reacting to AWS lifecycle notices.** Example: AWS announced that from April 2027, CloudWatch Logs log-group actions will require a log-group ARN instead of a log-stream ARN.
  1. I scanned all customer-managed and inline policies with the AWS CLI.
  2. I found the one affected statement.
  3. I added the log-group ARN as a new policy version, keeping the old version for rollback.
  4. I verified the result with `iam simulate-custom-policy`.

## Auditing with read-only tooling

[`scripts/aws-inventory.sh`](../scripts/aws-inventory.sh) uses only `Describe*`, `List*` and `Get*` calls. It collects the network, security groups, instances, databases, buckets, IAM users and cost. The output feeds the documentation and a periodic security review.
