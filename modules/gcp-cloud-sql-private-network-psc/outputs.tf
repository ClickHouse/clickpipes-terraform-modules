output "cloud_sql_instance_name" {
  description = "Cloud SQL instance name."
  value       = google_sql_database_instance.postgres.name
}

output "cloud_sql_private_ip" {
  description = "Cloud SQL private IP address."
  value       = google_sql_database_instance.postgres.private_ip_address
}

output "producer_service_attachment" {
  description = "Producer-owned PSC service attachment URI."
  value       = google_compute_service_attachment.cloud_sql.id
}

output "database_host" {
  description = "Private DNS host mapped through the RPE."
  value       = local.db_host
}

output "database_name" {
  description = "Created database name."
  value       = google_sql_database.database.name
}

output "database_user" {
  description = "Created database user."
  value       = google_sql_user.database_user.name
}

output "database_password" {
  description = "Database password."
  value       = local.database_password
  sensitive   = true
}

output "reverse_private_endpoint_ids" {
  description = "ClickPipes Reverse Private Endpoint IDs."
  value       = [clickhouse_clickpipes_reverse_private_endpoint.cloud_sql.id]
}

output "reverse_private_endpoint_statuses" {
  description = "ClickPipes Reverse Private Endpoint statuses."
  value = {
    cloud_sql = clickhouse_clickpipes_reverse_private_endpoint.cloud_sql.status
  }
}

output "endpoint_ids" {
  description = "Provider-side endpoint IDs created for the RPEs."
  value       = [clickhouse_clickpipes_reverse_private_endpoint.cloud_sql.endpoint_id]
}

output "clickpipe_id" {
  description = "ClickPipe ID when create_clickpipe is true."
  value       = try(clickhouse_clickpipe.cloud_sql[0].id, null)
}

output "clickpipe_state" {
  description = "ClickPipe state when create_clickpipe is true."
  value       = try(clickhouse_clickpipe.cloud_sql[0].state, null)
}
