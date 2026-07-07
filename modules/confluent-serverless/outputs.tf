output "environment_id" {
  description = "Confluent environment ID."
  value       = confluent_environment.main.id
}

output "cluster_id" {
  description = "Confluent Kafka cluster ID."
  value       = confluent_kafka_cluster.serverless.id
}

output "gateway_id" {
  description = "Confluent ingress gateway ID."
  value       = confluent_gateway.serverless.id
}

output "cloud" {
  description = "Confluent Cloud provider."
  value       = local.cloud
}

output "gateway_vpc_endpoint_service_name" {
  description = "AWS VPC endpoint service name for the ingress PrivateLink gateway. Null for non-AWS deployments."
  value       = local.aws_vpc_endpoint_service_name
}

output "gateway_service_attachment" {
  description = "GCP PSC service attachment URI for the ingress gateway. Null for non-GCP deployments."
  value       = local.gcp_service_attachment
}

output "access_point_id" {
  description = "Confluent ingress access point ID."
  value       = confluent_access_point.serverless.id
}

output "access_point_dns_domain" {
  description = "Confluent access point DNS domain."
  value       = local.access_point_dns_domain
}

output "glb_dns_domain" {
  description = "Confluent GLB DNS domain mapped through the ClickPipes DNS proxy."
  value       = local.glb_dns_domain
}

output "custom_private_dns_mappings" {
  description = "Custom private DNS mapping names configured on the ClickPipes RPE."
  value       = local.custom_private_dns_mappings[*].private_dns_name
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
