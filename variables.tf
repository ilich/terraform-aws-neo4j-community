variable "password" {
  description = "Password for Neo4j database"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.password) >= 8
    error_message = "Password must be at least 8 characters long."
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
