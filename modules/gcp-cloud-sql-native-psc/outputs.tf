output "cloud_sql_instance_name" {
  description = "Cloud SQL instance name."
  value       = google_sql_database_instance.postgres.name
}

output "cloud_sql_dns_name" {
  description = "Cloud SQL native PSC DNS name."
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

output "psc_service_attachment" {
  description = "Cloud SQL native PSC service attachment URI."
  value       = google_sql_database_instance.postgres.psc_service_attachment_link
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
