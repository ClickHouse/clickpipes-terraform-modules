output "cluster_name" {
  description = "Managed Kafka cluster ID."
  value       = google_managed_kafka_cluster.kafka.cluster_id
}

output "kafka_dns_zone" {
  description = "Private DNS zone used by Managed Kafka broker and bootstrap names."
  value       = local.kafka_dns_zone
}

output "bootstrap_address" {
  description = "Kafka bootstrap address to use through ClickPipes RPE DNS mapping."
  value       = "bootstrap.${local.kafka_dns_zone}:9092"
}

output "psc_service_attachments" {
  description = "Map of broker key to PSC service attachment URI and DNS name."
  value = {
    for key in local.sorted_broker_keys : key => {
      service_attachment_uri = google_compute_service_attachment.kafka[key].id
      dns_name               = "${key}.${local.kafka_dns_zone}"
      broker_ip              = local.broker_ip_by_key[key]
      ilb_ip                 = google_compute_address.kafka[key].address
    }
  }
}

output "sasl_username" {
  description = "SASL/PLAIN username for Managed Kafka."
  value       = google_service_account.kafka_client.email
}

output "sasl_password" {
  description = "SASL/PLAIN password for Managed Kafka."
  value       = google_service_account_key.kafka_client.private_key
  sensitive   = true
}

output "reverse_private_endpoint_ids" {
  description = "ClickPipes Reverse Private Endpoint IDs in broker order."
  value       = [for key in local.sorted_broker_keys : try(clickhouse_clickpipes_reverse_private_endpoint.kafka[key].id, null)]
}

output "reverse_private_endpoint_statuses" {
  description = "ClickPipes Reverse Private Endpoint statuses keyed by broker."
  value       = { for key in local.sorted_broker_keys : key => try(clickhouse_clickpipes_reverse_private_endpoint.kafka[key].status, null) }
}

output "endpoint_ids" {
  description = "Provider-side endpoint IDs in broker order."
  value       = [for key in local.sorted_broker_keys : try(clickhouse_clickpipes_reverse_private_endpoint.kafka[key].endpoint_id, null)]
}

output "clickpipe_id" {
  description = "ClickPipe ID when create_clickpipe is true."
  value       = try(clickhouse_clickpipe.kafka[0].id, null)
}

output "clickpipe_state" {
  description = "ClickPipe state when create_clickpipe is true."
  value       = try(clickhouse_clickpipe.kafka[0].state, null)
}
