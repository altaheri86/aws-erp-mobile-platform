#!/usr/bin/env bash
# Read-only AWS inventory for documentation and security reviews.
#
# Uses only Describe*/List*/Get* calls — it changes nothing in the account.
# Output: one JSON/text file per service in ./inventory-<region>-<date>/
#
# Usage:   ./aws-inventory.sh [region]      (default: the CLI's configured region)
# Needs:   AWS CLI v2, credentials with read-only access (e.g. the ReadOnlyAccess
#          managed policy), and `ce:GetCostAndUsage` for the cost report.
#
# The output contains account IDs, IPs and resource names: keep it private.
set -u

R="${1:-$(aws configure get region)}"
OUT="inventory-${R}-$(date +%Y%m%d)"
mkdir -p "$OUT" && cd "$OUT" || exit 1

run() {  # run <file> <aws args...> ; keeps going if one service is not available
  local f="$1"; shift
  if ! aws "$@" > "$f" 2> "$f.err"; then echo "  ! $f: $(head -1 "$f.err")"; else rm -f "$f.err"; fi
}

echo "Account: $(aws sts get-caller-identity --query Account --output text) · Region: $R"

echo "Regions with EC2 or RDS:"
for r in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do
  n=$(aws ec2 describe-instances --region "$r" --query "length(Reservations[].Instances[])" --output text 2>/dev/null)
  d=$(aws rds describe-db-instances --region "$r" --query "length(DBInstances)" --output text 2>/dev/null)
  [ "${n:-0}${d:-0}" != "00" ] && echo "  $r  ec2=$n  rds=$d"
done

# Network
run vpcs.json             ec2 describe-vpcs --region "$R"
run subnets.json          ec2 describe-subnets --region "$R"
run route-tables.json     ec2 describe-route-tables --region "$R"
run igw.json              ec2 describe-internet-gateways --region "$R"
run nat.json              ec2 describe-nat-gateways --region "$R"
run vpc-endpoints.json    ec2 describe-vpc-endpoints --region "$R"
run security-groups.json  ec2 describe-security-groups --region "$R"
run eips.json             ec2 describe-addresses --region "$R"
run load-balancers.json   elbv2 describe-load-balancers --region "$R"
run sg-usage.txt          ec2 describe-network-interfaces --region "$R" --output text \
  --query "NetworkInterfaces[].[InterfaceType,Groups[].GroupName|join(',',@),SubnetId,Description]"

# Compute + storage
run ec2.json              ec2 describe-instances --region "$R"
run volumes.json          ec2 describe-volumes --region "$R"
run amis.json             ec2 describe-images --region "$R" --owners self
run ebs-snapshots.json    ec2 describe-snapshots --region "$R" --owner-ids self
run s3.json               s3api list-buckets

# Databases
run rds.json              rds describe-db-instances --region "$R"
run rds-subnet-groups.json rds describe-db-subnet-groups --region "$R"
run rds-snapshots.json    rds describe-db-snapshots --region "$R" --snapshot-type manual

# Identity + monitoring
run iam-users.json        iam list-users
run iam-roles.json        iam list-roles
run alarms.json           cloudwatch describe-alarms --region "$R"
run log-groups.json       logs describe-log-groups --region "$R"
run backup-plans.json     backup list-backup-plans --region "$R"

# Last full month of cost, by service
FIRST=$(date -d "$(date +%Y-%m-01) -1 month" +%Y-%m-01)
run cost.json ce get-cost-and-usage --time-period Start="$FIRST",End="$(date +%Y-%m-01)" \
  --granularity MONTHLY --metrics UnblendedCost --group-by Type=DIMENSION,Key=SERVICE

# Quick security signals
echo "Security groups with ports open to 0.0.0.0/0:"
aws ec2 describe-security-groups --region "$R" --output text \
  --query "SecurityGroups[].IpPermissions[?IpRanges[?CidrIp=='0.0.0.0/0']][].[FromPort,ToPort,IpProtocol]" | sort -u | sed 's/^/  /'
echo "Unattached Elastic IPs:"
aws ec2 describe-addresses --region "$R" --query "Addresses[?AssociationId==null].PublicIp" --output text | sed 's/^/  /'
echo "Unencrypted EBS volumes:"
aws ec2 describe-volumes --region "$R" --query "Volumes[?Encrypted==\`false\`].VolumeId" --output text | sed 's/^/  /'
echo "Publicly accessible RDS instances:"
aws rds describe-db-instances --region "$R" --query "DBInstances[?PubliclyAccessible].DBInstanceIdentifier" --output text | sed 's/^/  /'

echo "Done: $(pwd)"
