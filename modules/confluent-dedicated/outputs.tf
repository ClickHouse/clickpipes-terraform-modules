output "environment_id" {
  description = "Confluent environment ID."
  value       = confluent_environment.main.id
}

output "cluster_id" {
  description = "Confluent Kafka cluster ID."
  value       = confluent_kafka_cluster.dedicated.id
}

output "cloud" {
  description = "Confluent Cloud provider."
  value       = local.cloud
}

output "bootstrap_endpoint" {
  description = "Confluent bootstrap endpoint used by ClickPipes."
  value       = local.bootstrap_address
}

output "dns_domain" {
  description = "Confluent private networking DNS domain."
  value       = local.dns_domain
}

output "vpc_endpoint_service_name" {
  description = "Confluent AWS VPC endpoint service name. Null for non-AWS deployments."
  value       = local.aws_vpc_endpoint_service_name
}

output "service_attachments" {
  description = "Confluent GCP PSC service attachments keyed by zone. Empty for non-GCP deployments."
  value = local.is_gcp ? {
    for zone in local.sorted_zones : zone => local.gcp_service_attachments[zone]
  } : {}
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
  description = "ClickPipes Reverse Private Endpoint IDs in deterministic order."
  value = [
    for key in sort(keys(clickhouse_clickpipes_reverse_private_endpoint.dedicated)) :
    clickhouse_clickpipes_reverse_private_endpoint.dedicated[key].id
  ]
}

output "reverse_private_endpoint_statuses" {
  description = "ClickPipes Reverse Private Endpoint statuses keyed by RPE key."
  value = {
    for key in sort(keys(clickhouse_clickpipes_reverse_private_endpoint.dedicated)) :
    key => clickhouse_clickpipes_reverse_private_endpoint.dedicated[key].status
  }
}

output "endpoint_ids" {
  description = "Provider-side endpoint IDs in deterministic order."
  value = [
    for key in sort(keys(clickhouse_clickpipes_reverse_private_endpoint.dedicated)) :
    clickhouse_clickpipes_reverse_private_endpoint.dedicated[key].endpoint_id
  ]
}

output "clickpipe_id" {
  description = "ClickPipe ID when create_clickpipe is true."
  value       = try(clickhouse_clickpipe.dedicated[0].id, null)
}

output "clickpipe_state" {
  description = "ClickPipe state when create_clickpipe is true."
  value       = try(clickhouse_clickpipe.dedicated[0].state, null)
}
