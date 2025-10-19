terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Secrets Manager Secret for Neo4j Password
resource "aws_secretsmanager_secret" "neo4j_password" {
  name_prefix = "${var.name_prefix}-neo4j-password-"
  description = "Neo4j database password"

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-neo4j-password"
    }
  )
}

resource "aws_secretsmanager_secret_version" "neo4j_password" {
  secret_id     = aws_secretsmanager_secret.neo4j_password.id
  secret_string = var.neo4j_password
}

# Neo4j Module
module "neo4j" {
  source = "../.."

  password_secret_arn     = aws_secretsmanager_secret.neo4j_password.arn
  vpc_id                  = var.vpc_id
  subnet_id               = var.subnet_id
  instance_type           = var.instance_type
  disk_size               = var.disk_size
  snapshot_retention_days = var.snapshot_retention_days
  region                  = var.region

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-neo4j"
    }
  )
}
