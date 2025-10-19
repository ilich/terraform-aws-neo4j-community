# Neo4j Community Edition Terraform Module

This Terraform module deploys a single-node Neo4j Community Edition instance on AWS EC2. 

Neo4j recommended system requirements: https://neo4j.com/docs/operations-manual/2025.09/installation/requirements/

## Features

- Single EC2 instance running Neo4j Community Edition
- Automated installation and configuration via user data script
- Security group with HTTP Browser (7474) and Bolt protocol (7687) access
- AWS Systems Manager Session Manager for secure console access (no SSH required)
- IAM role and instance profile configured for SSM
- APOC plugin pre-installed
- Encrypted EBS volumes
- Configurable instance types from t3.medium to r6i.32xlarge
- Automatic memory configuration based on instance size

## Usage

```hcl
module "neo4j" {
  source = "github.com/ilich/terraform-aws-neo4j-community"

  password  = "your-secure-password"
  vpc_id    = "vpc-xxxxx"
  subnet_id = "subnet-xxxxx"

  # Optional variables
  instance_type = "t3.medium"
  disk_size     = 20
  stack_name    = "my-neo4j"

  tags = {
    Environment = "dev"
    Project     = "my-project"
  }
}
```

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
| password | Password for Neo4j database (minimum 8 characters) | `string` | n/a | yes |
| vpc_id | VPC ID to use for Neo4j | `string` | n/a | yes |
| subnet_id | Subnet ID to use for Neo4j | `string` | n/a | yes |
| instance_type | EC2 instance type | `string` | `"r6i.large"` | no |
| disk_size | Size in GB of the EBS volume (minimum 10) | `number` | `20` | no |
| region | AWS region for deployment | `string` | `null` (uses current region) | no |
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
# Initialize Terraform
terraform init

# Review the plan
terraform plan -var="password=YourSecurePassword123" \
  -var="vpc_id=vpc-xxxxx" \
  -var="subnet_id=subnet-xxxxx"

# Apply the configuration
terraform apply -var="password=YourSecurePassword123" \
  -var="vpc_id=vpc-xxxxx" \
  -var="subnet_id=subnet-xxxxx"
```

Alternatively, create a `terraform.tfvars` file:

```hcl
password      = "YourSecurePassword123"
vpc_id        = "vpc-xxxxx"
subnet_id     = "subnet-xxxxx"
instance_type = "t3.large"
disk_size     = 50
stack_name    = "production-neo4j"

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
- Password: The password you provided in the `password` variable

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

## Security Considerations

1. **Instance Access**: No SSH access - uses AWS Systems Manager Session Manager for secure console access
2. **Neo4j Ports**: Consider restricting ports 7474 and 7687 to specific IP ranges by modifying the security group
3. **Password**: Use a strong password and store it securely (e.g., in AWS Secrets Manager)
4. **Encryption**: EBS volumes are encrypted by default
5. **IAM Permissions**: The instance has minimal IAM permissions (only SSM access)
