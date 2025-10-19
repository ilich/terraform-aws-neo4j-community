output "neo4j_browser_url" {
  description = "URL for Neo4j Browser"
  value       = "http://${aws_instance.neo4j.public_dns}:7474"
}

output "neo4j_uri" {
  description = "Neo4j URI for Bolt protocol connections"
  value       = "neo4j://${aws_instance.neo4j.public_dns}:7687"
}

output "neo4j_username" {
  description = "The username is neo4j. The password is what you provided to the module."
  value       = "neo4j"
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.neo4j.id
}
