# 04 — Roadmap

The platform works, and the next iteration moves it toward a fully managed, hands-off AWS setup. Planned work:

| Area | Next step | Benefit |
|---|---|---|
| **Edge** | Application Load Balancer with ACM certificates (optionally CloudFront + AWS WAF) | Managed TLS, health checks, room for a second app instance |
| **Network** | Move app servers to private subnets behind the ALB, and add VPC endpoints for S3 and SSM | No public IPs on instances |
| **Admin access** | AWS Systems Manager Session Manager + IAM Identity Center (SSO) | No SSH keys to manage, audited sessions, short-lived credentials |
| **Hybrid link** | Site-to-Site VPN between the office and the VPC | DR replication over IPsec, so databases need no public endpoint |
| **Backups** | AWS Backup plans for EC2 + RDS, with a cross-region copy | One policy for every resource, and off-region copies |
| **Alerting** | CloudWatch alarms (CPU, disk, RDS free storage, replication-slot lag) → SNS | Problems reach a person before users notice |
| **Availability** | RDS Multi-AZ for the ERP database | Automatic failover inside the region |
| **Infrastructure as Code** | Bring the whole stack into Terraform, with state in S3 + DynamoDB locking | Repeatable environments and reviewed changes |
| **Media delivery** | CloudFront in front of S3 with Origin Access Control | Faster media, and the bucket stays private |
| **Cost** | Savings Plans for the always-on instances | About 30% lower compute and DB spend |
