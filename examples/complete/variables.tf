variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "neo4j-example"
}

variable "neo4j_password" {
  description = "Password for Neo4j database (minimum 8 characters)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.neo4j_password) >= 8
    error_message = "Password must be at least 8 characters long."
  }
}

variable "instance_type" {
  description = "EC2 instance type for Neo4j"
  type        = string
  default     = "r6i.large"
}

variable "disk_size" {
  description = "Size in GB of the EBS volume"
  type        = number
  default     = 20
}

variable "snapshot_retention_days" {
  description = "Number of days to retain daily EBS snapshots (0 to disable)"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "demo"
    ManagedBy   = "terraform"
    Example     = "complete"
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