resource "google_project_service" "sqladmin" {
  project = var.project_id
  service = "sqladmin.googleapis.com"

  disable_on_destroy = false
}

resource "random_password" "database_user" {
  count = var.database_password == null ? 1 : 0

  length  = 24
  special = false
}

locals {
  database_password = var.database_password != null ? var.database_password : random_password.database_user[0].result
  db_host           = trimsuffix(google_sql_database_instance.postgres.dns_name, ".")
}

resource "google_sql_database_instance" "postgres" {
  project             = var.project_id
  name                = var.name_prefix
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    availability_type = "ZONAL"

    backup_configuration {
      enabled = true
    }

    ip_configuration {
      ipv4_enabled = false

      psc_config {
        psc_enabled               = true
        allowed_consumer_projects = var.psc_allowed_consumer_projects
      }
    }
  }

  depends_on = [google_project_service.sqladmin]
}

resource "google_sql_database" "database" {
  project  = var.project_id
  name     = var.database_name
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_user" "database_user" {
  project  = var.project_id
  name     = var.database_user
  instance = google_sql_database_instance.postgres.name
  password = local.database_password
}

resource "clickhouse_clickpipes_reverse_private_endpoint" "cloud_sql" {
  service_id             = var.clickhouse_service_id
  description            = var.rpe_description
  type                   = "GCP_PSC_SERVICE_ATTACHMENT"
  gcp_service_attachment = google_sql_database_instance.postgres.psc_service_attachment_link
}

resource "clickhouse_clickpipes_reverse_private_endpoint_custom_private_dns" "cloud_sql" {
  service_id                  = var.clickhouse_service_id
  reverse_private_endpoint_id = clickhouse_clickpipes_reverse_private_endpoint.cloud_sql.id

  mapping = [
    {
      private_dns_name = local.db_host
    }
  ]
}

resource "clickhouse_clickpipe" "cloud_sql" {
  count = var.create_clickpipe ? 1 : 0

  name       = var.clickpipe_name
  service_id = var.clickhouse_service_id

  depends_on = [clickhouse_clickpipes_reverse_private_endpoint_custom_private_dns.cloud_sql]

  source = {
    postgres = {
      type           = "cloudsqlpostgres"
      host           = local.db_host
      port           = 5432
      database       = google_sql_database.database.name
      authentication = "basic"

      credentials = {
        username = google_sql_user.database_user.name
        password = local.database_password
      }

      settings = {
        replication_mode = var.replication_mode
      }

      table_mappings = [
        {
          source_schema_name = var.source_schema
          source_table       = var.source_table
          target_table       = var.target_table
          table_engine       = var.table_engine
        }
      ]
    }
  }

  destination = {
    database = var.destination_database
  }

  lifecycle {
    precondition {
      condition     = !var.create_clickpipe || (var.source_table != null && var.target_table != null)
      error_message = "source_table and target_table must be set when create_clickpipe is true."
    }
  }
}
