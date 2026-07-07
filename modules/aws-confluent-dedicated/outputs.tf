output "environment_id" {
  description = "Confluent environment ID."
  value       = confluent_environment.main.id
}

output "cluster_id" {
  description = "Confluent Kafka cluster ID."
  value       = confluent_kafka_cluster.dedicated.id
}

output "bootstrap_endpoint" {
  description = "Confluent bootstrap endpoint used by ClickPipes."
  value       = local.bootstrap_address
}

output "dns_domain" {
  description = "Confluent PrivateLink DNS domain."
  value       = local.dns_domain
}

output "vpc_endpoint_service_name" {
  description = "Confluent AWS VPC endpoint service name."
  value       = confluent_network.dedicated.aws[0].private_link_endpoint_service
}

output "kafka_api_key" {
  description = "Kafka API key used by ClickPipes."
  value       = confluent_api_key.clickpipes.id
  sensitive   = true
}

output "kafka_api_secret" {
  description = "Kafka API secret used by ClickPipes."
  value       = confluent_api_key.clickpipes.secret
  sensitive   = true
}

output "reverse_private_endpoint_ids" {
  description = "ClickPipes Reverse Private Endpoint IDs."
  value       = [clickhouse_clickpipes_reverse_private_endpoint.dedicated.id]
}

output "reverse_private_endpoint_statuses" {
  description = "ClickPipes Reverse Private Endpoint statuses."
  value = {
    dedicated = clickhouse_clickpipes_reverse_private_endpoint.dedicated.status
  }
}

output "endpoint_ids" {
  description = "Provider-side endpoint IDs."
  value       = [clickhouse_clickpipes_reverse_private_endpoint.dedicated.endpoint_id]
}

output "clickpipe_id" {
  description = "ClickPipe ID when create_clickpipe is true."
  value       = try(clickhouse_clickpipe.dedicated[0].id, null)
}

output "clickpipe_state" {
  description = "ClickPipe state when create_clickpipe is true."
  value       = try(clickhouse_clickpipe.dedicated[0].state, null)
}
