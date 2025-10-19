# Neo4j Community Edition Terraform Module

This Terraform module deploys a single-node Neo4j Community Edition instance on AWS EC2.

Neo4j recommended system requirements: https://neo4j.com/docs/operations-manual/current/installation/requirements/

## Features

- Single EC2 instance running Neo4j Community Edition on Amazon Linux 2023
- Automated installation and configuration via user data script
- Latest Neo4j version automatically fetched from official repositories
- Security group with HTTP Browser (7474) and Bolt protocol (7687) access
- AWS Systems Manager Session Manager for secure console access (no SSH required)
- IAM role and instance profile configured for SSM
- APOC plugin pre-installed
- Encrypted EBS volumes (GP3)
- EBS-optimized instances
- Automatic memory configuration based on instance size
- Cypher IP blocklist configured for internal network protection
- Optional automated daily EBS snapshots with configurable retention

## Prerequisites

### AWS Secrets Manager Secret

Before deploying the module, create a secret in AWS Secrets Manager to store your Neo4j password:

**Using AWS CLI:**
```bash
aws secretsmanager create-secret \
  --name neo4j-password \
  --description "Neo4j database password" \
  --secret-string "YourSecurePassword123"
```

**Using Terraform:**
```hcl
resource "aws_secretsmanager_secret" "neo4j_password" {
  name        = "neo4j-password"
  description = "Neo4j database password"
}

resource "aws_secretsmanager_secret_version" "neo4j_password" {
  secret_id     = aws_secretsmanager_secret.neo4j_password.id
  secret_string = "YourSecurePassword123"  # Minimum 8 characters
}
```

**Important Notes:**
- The secret must contain a **plain text string** (not JSON)
- Password must be at least **8 characters** long
- The secret must be in the same region as your Neo4j deployment (or specify the region explicitly)

## Usage

```hcl
module "neo4j" {
  source = "github.com/ilich/terraform-aws-neo4j-community"

  password_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:neo4j-password-xxxxx"
  vpc_id              = "vpc-xxxxx"
  subnet_id           = "subnet-xxxxx"

  # Optional variables
  instance_type           = "t3.medium"
  disk_size              = 20
  snapshot_retention_days = 7  # Enable daily snapshots, retain for 7 days

  tags = {
    Environment = "dev"
    Project     = "my-project"
  }
}
```

**Using with Terraform-managed secret:**
```hcl
resource "aws_secretsmanager_secret" "neo4j_password" {
  name = "neo4j-password"
}

resource "aws_secretsmanager_secret_version" "neo4j_password" {
  secret_id     = aws_secretsmanager_secret.neo4j_password.id
  secret_string = var.neo4j_password
}

module "neo4j" {
  source = "github.com/ilich/terraform-aws-neo4j-community"

  password_secret_arn = aws_secretsmanager_secret.neo4j_password.arn
  vpc_id              = "vpc-xxxxx"
  subnet_id           = "subnet-xxxxx"
}
```

For a complete working example including VPC setup, see [examples/complete](./examples/complete).

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| password_secret_arn | ARN of AWS Secrets Manager secret containing Neo4j password (plain text, minimum 8 characters) | `string` | n/a | yes |
| vpc_id | VPC ID to use for Neo4j | `string` | n/a | yes |
| subnet_id | Subnet ID to use for Neo4j | `string` | n/a | yes |
| instance_type | EC2 instance type | `string` | `"r6i.large"` | no |
| disk_size | Size in GB of the EBS volume (minimum 10) | `number` | `20` | no |
| region | AWS region for deployment | `string` | `null` (uses current region) | no |
| snapshot_retention_days | Number of days to retain daily EBS snapshots. Set to 0 to disable snapshots. | `number` | `0` | no |
| tags | Additional tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| neo4j_browser_url | URL for Neo4j Browser |
| neo4j_uri | Neo4j URI for Bolt protocol connections |
| neo4j_username | Username for Neo4j (always "neo4j") |
| instance_id | EC2 instance ID |

## Example Deployment

```bash
# Create the secret first
aws secretsmanager create-secret \
  --name neo4j-password \
  --secret-string "YourSecurePassword123"

# Get the secret ARN
SECRET_ARN=$(aws secretsmanager describe-secret --secret-id neo4j-password --query ARN --output text)

# Initialize Terraform
terraform init

# Review the plan
terraform plan \
  -var="password_secret_arn=$SECRET_ARN" \
  -var="vpc_id=vpc-xxxxx" \
  -var="subnet_id=subnet-xxxxx"

# Apply the configuration
terraform apply \
  -var="password_secret_arn=$SECRET_ARN" \
  -var="vpc_id=vpc-xxxxx" \
  -var="subnet_id=subnet-xxxxx"
```

Alternatively, create a `terraform.tfvars` file:

```hcl
password_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:neo4j-password-xxxxx"
vpc_id              = "vpc-xxxxx"
subnet_id           = "subnet-xxxxx"
instance_type       = "t3.large"
disk_size           = 50

tags = {
  Environment = "production"
  ManagedBy   = "terraform"
}
```

Then run:
```bash
terraform init
terraform plan
terraform apply
```

## Accessing Neo4j

### Neo4j Browser and Database Access

After deployment, you can access Neo4j using the outputs:

```bash
# Get the Neo4j Browser URL
terraform output neo4j_browser_url

# Get the Bolt connection URI
terraform output neo4j_uri
```

Default credentials:
- Username: `neo4j`
- Password: The password stored in your AWS Secrets Manager secret

### Instance Console Access via SSM Session Manager

This module uses AWS Systems Manager Session Manager for secure console access instead of SSH. No SSH keys or open port 22 required.

**Connect via AWS Console:**
1. Navigate to EC2 console
2. Select your Neo4j instance
3. Click "Connect" → "Session Manager" tab
4. Click "Connect"

**Connect via AWS CLI:**
```bash
# Get the instance ID
INSTANCE_ID=$(terraform output -raw instance_id)

# Start a session
aws ssm start-session --target $INSTANCE_ID
```

**Prerequisites for CLI access:**
- AWS CLI v2 installed
- Session Manager plugin installed: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
- Appropriate IAM permissions for SSM

**Note:** The subnet where the instance is deployed must have:
- Either a NAT Gateway/Instance for internet access, OR
- VPC endpoints for SSM services (ssm, ssmmessages, ec2messages)

## EBS Snapshots

The module supports automated daily EBS snapshots using AWS Data Lifecycle Manager (DLM):

### Enabling Snapshots

Set the `snapshot_retention_days` parameter to a value greater than 0:

```hcl
module "neo4j" {
  source = "github.com/ilich/terraform-aws-neo4j-community"

  password_secret_arn     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:neo4j-password-xxxxx"
  vpc_id                  = "vpc-xxxxx"
  subnet_id               = "subnet-xxxxx"
  snapshot_retention_days = 30  # Keep daily snapshots for 30 days
}
```

### How It Works

- **Daily Schedule**: Snapshots are created daily at 03:00 UTC
- **Automatic Retention**: Snapshots are automatically deleted after the specified retention period
- **Tagging**: Snapshots are tagged with `SnapshotType=DLM`, `Service=Neo4j`, plus any custom tags
- **Target Identification**: The EBS volume is tagged with `neo4j-snapshot=true` for DLM targeting
- **IAM Role**: An IAM role is automatically created for DLM with minimal required permissions

### Disabling Snapshots

Set `snapshot_retention_days = 0` (default) or omit the parameter entirely:

```hcl
module "neo4j" {
  source = "github.com/ilich/terraform-aws-neo4j-community"

  password_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:neo4j-password-xxxxx"
  vpc_id              = "vpc-xxxxx"
  subnet_id           = "subnet-xxxxx"
  # snapshot_retention_days = 0  # Default - snapshots disabled
}
```

### Cost Considerations

- EBS snapshot costs are based on the amount of data stored
- Snapshots are incremental, so subsequent snapshots only store changed data
- Review AWS EBS pricing for your region: https://aws.amazon.com/ebs/pricing/

## Security Considerations

1. **Instance Access**: No SSH access - uses AWS Systems Manager Session Manager for secure console access
2. **Neo4j Ports**: Ports 7474 and 7687 are open to 0.0.0.0/0 by default. Consider restricting to specific IP ranges by modifying the security group
3. **Password Management**:
   - Password is stored in AWS Secrets Manager (never in Terraform state)
   - Must be at least 8 characters long
   - EC2 instance fetches password at boot time using IAM role
   - Secrets Manager secret must be in the same region as deployment
4. **Encryption**: EBS volumes are encrypted by default using AWS-managed keys
5. **IAM Permissions**: The instance has minimal IAM permissions:
   - SSM access via AmazonSSMManagedInstanceCore policy
   - Read-only access to the specific Secrets Manager secret (secretsmanager:GetSecretValue)
6. **Cypher Security**: Internal network IP blocklist is configured to prevent SSRF attacks via Cypher queries
7. **AMI**: Uses Amazon Linux 2023 AMI (al2023-ami-2023.9.20250929.0-kernel-6.1-x86_64) with lifecycle policy to ignore AMI changes

## Supported Regions

This module includes AMI mappings for the following AWS regions:
- US: us-east-1, us-east-2, us-west-1, us-west-2
- EU: eu-north-1, eu-west-1, eu-west-2, eu-west-3, eu-central-1
- AP: ap-south-1, ap-northeast-1, ap-northeast-2, ap-northeast-3, ap-southeast-1, ap-southeast-2
- CA: ca-central-1
- SA: sa-east-1

If deployed in an unsupported region, the module will fall back to the us-east-1 AMI.
