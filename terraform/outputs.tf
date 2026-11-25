output "environment_id" {
  value = confluent_environment.demo.id
}

output "cluster_id" {
  value = confluent_kafka_cluster.demo.id
}

output "bootstrap_servers" {
  value = replace(confluent_kafka_cluster.demo.bootstrap_endpoint, "SASL_SSL://", "")
}

output "schema_registry_url" {
  value = data.confluent_schema_registry_cluster.demo.rest_endpoint
}

output "mcp_url" {
  description = "Lambda MCP endpoint (needs the bearer token)."
  value       = local.mcp_url
}

output "mcp_token" {
  description = "Bearer token for the MCP server. Run: terraform output -raw mcp_token"
  value       = random_password.mcp_token.result
  sensitive   = true
}

output "ses_verification_note" {
  value = "SES sent a verification email to NOTIFY_EMAIL. Click the link before the first run, or no email will be delivered."
}

# Client settings for the Python scripts. Git-ignored, mode 0600.
resource "local_sensitive_file" "client_env" {
  filename        = "${path.module}/../.generated/client.env"
  file_permission = "0600"
  content         = <<-EOT
    BOOTSTRAP_SERVERS=${replace(confluent_kafka_cluster.demo.bootstrap_endpoint, "SASL_SSL://", "")}
    KAFKA_API_KEY=${confluent_api_key.kafka.id}
    KAFKA_API_SECRET=${confluent_api_key.kafka.secret}
    SCHEMA_REGISTRY_URL=${data.confluent_schema_registry_cluster.demo.rest_endpoint}
    SCHEMA_REGISTRY_API_KEY=${confluent_api_key.schema_registry.id}
    SCHEMA_REGISTRY_API_SECRET=${confluent_api_key.schema_registry.secret}
  EOT
}
