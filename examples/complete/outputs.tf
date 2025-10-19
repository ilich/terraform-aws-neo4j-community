output "neo4j_browser_url" {
  description = "URL for Neo4j Browser"
  value       = module.neo4j.neo4j_browser_url
}

output "neo4j_uri" {
  description = "Neo4j URI for Bolt protocol connections"
  value       = module.neo4j.neo4j_uri
}

output "neo4j_username" {
  description = "Username for Neo4j"
  value       = module.neo4j.neo4j_username
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = module.neo4j.instance_id
}

output "secrets_manager_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the Neo4j password"
  value       = aws_secretsmanager_secret.neo4j_password.arn
}
