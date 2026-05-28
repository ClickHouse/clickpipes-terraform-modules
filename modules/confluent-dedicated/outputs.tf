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
  description = "Confluent PSC DNS domain."
  value       = local.dns_domain
}

output "service_attachments" {
  description = "Confluent PSC service attachments keyed by zone."
  value = {
    for zone in local.sorted_zones : zone => confluent_network.dedicated.gcp[0].private_service_connect_service_attachments[zone]
  }
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
  description = "ClickPipes Reverse Private Endpoint IDs in zone order."
  value       = [for zone in local.sorted_zones : clickhouse_clickpipes_reverse_private_endpoint.dedicated[zone].id]
}

output "reverse_private_endpoint_statuses" {
  description = "ClickPipes Reverse Private Endpoint statuses keyed by zone."
  value       = { for zone in local.sorted_zones : zone => clickhouse_clickpipes_reverse_private_endpoint.dedicated[zone].status }
}

output "endpoint_ids" {
  description = "Provider-side endpoint IDs in zone order."
  value       = [for zone in local.sorted_zones : clickhouse_clickpipes_reverse_private_endpoint.dedicated[zone].endpoint_id]
}

output "clickpipe_id" {
  description = "ClickPipe ID when create_clickpipe is true."
  value       = try(clickhouse_clickpipe.dedicated[0].id, null)
}

output "clickpipe_state" {
  description = "ClickPipe state when create_clickpipe is true."
  value       = try(clickhouse_clickpipe.dedicated[0].state, null)
}
