variable "password_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret containing the Neo4j password. The secret must be a plain text string (not JSON) with minimum 8 characters."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^arn:aws:secretsmanager:[a-z0-9-]+:[0-9]+:secret:", var.password_secret_arn))
    error_message = "Must be a valid AWS Secrets Manager ARN (format: arn:aws:secretsmanager:region:account:secret:name)."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "r6i.large"
}

variable "disk_size" {
  description = "Size in GB of the EBS volume"
  type        = number
  default     = 20

  validation {
    condition     = var.disk_size >= 10
    error_message = "Minimum disk size should be 10 GB according to https://neo4j.com/docs/operations-manual/current/installation/requirements/"
  }
}

variable "vpc_id" {
  description = "VPC ID to use for Neo4j"
  type        = string

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "Must be a valid VPC ID starting with 'vpc-'."
  }
}

variable "subnet_id" {
  description = "Subnet ID to use for Neo4j"
  type        = string

  validation {
    condition     = can(regex("^subnet-", var.subnet_id))
    error_message = "Must be a valid Subnet ID starting with 'subnet-'."
  }
}

variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "snapshot_retention_days" {
  description = "Number of days to retain daily EBS snapshots. Set to 0 to disable snapshots. If > 0, daily snapshots will be created and retained for the specified number of days."
  type        = number
  default     = 0

  validation {
    condition     = var.snapshot_retention_days >= 0
    error_message = "Snapshot retention days must be a non-negative number. Set to 0 to disable snapshots."
  }
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access Neo4j ports (7474 and 7687). Defaults to open access from anywhere."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.allowed_cidr_blocks) > 0
    error_message = "At least one CIDR block must be specified."
  }
}
