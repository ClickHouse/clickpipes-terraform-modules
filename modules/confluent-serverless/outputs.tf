output "environment_id" {
  description = "Confluent environment ID."
  value       = confluent_environment.main.id
}

output "cluster_id" {
  description = "Confluent Kafka cluster ID."
  value       = confluent_kafka_cluster.serverless.id
}

output "gateway_id" {
  description = "Confluent ingress PSC gateway ID."
  value       = confluent_gateway.serverless.id
}

output "gateway_service_attachment" {
  description = "Confluent ingress PSC gateway service attachment."
  value       = confluent_gateway.serverless.gcp_ingress_private_service_connect_gateway[0].private_service_connect_service_attachment
}

output "access_point_id" {
  description = "Confluent access point ID when create_access_point is true."
  value       = try(confluent_access_point.serverless[0].id, null)
}

output "access_point_dns_domain" {
  description = "Confluent access point DNS domain when create_access_point is true."
  value       = local.access_point_dns_domain
}

output "bootstrap_endpoint" {
  description = "Confluent bootstrap endpoint used by ClickPipes."
  value       = local.bootstrap_address
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
  value       = [clickhouse_clickpipes_reverse_private_endpoint.serverless.id]
}

output "reverse_private_endpoint_statuses" {
  description = "ClickPipes Reverse Private Endpoint statuses."
  value = {
    serverless = clickhouse_clickpipes_reverse_private_endpoint.serverless.status
  }
}

output "endpoint_ids" {
  description = "Provider-side endpoint IDs."
  value       = [clickhouse_clickpipes_reverse_private_endpoint.serverless.endpoint_id]
}

output "clickpipe_id" {
  description = "ClickPipe ID when create_clickpipe is true."
  value       = try(clickhouse_clickpipe.serverless[0].id, null)
}

output "clickpipe_state" {
  description = "ClickPipe state when create_clickpipe is true."
  value       = try(clickhouse_clickpipe.serverless[0].state, null)
}
