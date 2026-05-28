locals {
  db_host           = trimsuffix("${var.name_prefix}.${var.private_dns_domain}", ".")
  database_password = var.database_password != null ? var.database_password : random_password.database_user[0].result
}

resource "google_project_service" "sqladmin" {
  project = var.project_id
  service = "sqladmin.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "compute" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "servicenetworking" {
  project = var.project_id
  service = "servicenetworking.googleapis.com"

  disable_on_destroy = false
}

data "google_compute_zones" "available" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_network" "cloud_sql" {
  project                 = var.project_id
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "cloud_sql" {
  project       = var.project_id
  name          = "${var.name_prefix}-subnet"
  region        = var.region
  network       = google_compute_network.cloud_sql.id
  ip_cidr_range = var.subnet_cidr
}

resource "google_compute_subnetwork" "proxy_only" {
  project       = var.project_id
  name          = "${var.name_prefix}-proxy-only"
  region        = var.region
  network       = google_compute_network.cloud_sql.id
  ip_cidr_range = var.proxy_only_subnet_cidr
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

resource "google_compute_subnetwork" "psc_nat" {
  project       = var.project_id
  name          = "${var.name_prefix}-psc-nat"
  region        = var.region
  network       = google_compute_network.cloud_sql.id
  ip_cidr_range = var.psc_nat_subnet_cidr
  purpose       = "PRIVATE_SERVICE_CONNECT"
}

resource "google_compute_global_address" "private_services" {
  project       = var.project_id
  name          = "${var.name_prefix}-private-services"
  address       = var.private_service_access_cidr
  address_type  = "INTERNAL"
  prefix_length = var.private_service_access_prefix_length
  purpose       = "VPC_PEERING"
  network       = google_compute_network.cloud_sql.id
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.cloud_sql.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]

  depends_on = [google_project_service.servicenetworking]
}

resource "random_password" "database_user" {
  count = var.database_password == null ? 1 : 0

  length  = 24
  special = false
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
      ipv4_enabled    = false
      private_network = google_compute_network.cloud_sql.id
    }
  }

  depends_on = [
    google_project_service.sqladmin,
    google_service_networking_connection.private_services,
  ]
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

resource "google_compute_region_health_check" "cloud_sql" {
  project = var.project_id
  name    = "${var.name_prefix}-postgres-hc"
  region  = var.region

  tcp_health_check {
    port = 5432
  }

  check_interval_sec  = 30
  timeout_sec         = 10
  healthy_threshold   = 1
  unhealthy_threshold = 10
}

resource "google_compute_network_endpoint_group" "cloud_sql" {
  project               = var.project_id
  name                  = "${var.name_prefix}-postgres-neg"
  network               = google_compute_network.cloud_sql.id
  network_endpoint_type = "NON_GCP_PRIVATE_IP_PORT"
  default_port          = 5432
  zone                  = data.google_compute_zones.available.names[0]
}

resource "google_compute_network_endpoints" "cloud_sql" {
  project                = var.project_id
  zone                   = data.google_compute_zones.available.names[0]
  network_endpoint_group = google_compute_network_endpoint_group.cloud_sql.name

  network_endpoints {
    ip_address = google_sql_database_instance.postgres.private_ip_address
    port       = 5432
  }
}

resource "google_compute_region_backend_service" "cloud_sql" {
  project               = var.project_id
  name                  = "${var.name_prefix}-postgres-bs"
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  health_checks         = [google_compute_region_health_check.cloud_sql.id]

  backend {
    group                        = google_compute_network_endpoint_group.cloud_sql.id
    balancing_mode               = "CONNECTION"
    max_connections_per_endpoint = 1000
    capacity_scaler              = 1.0
  }

  depends_on = [google_compute_network_endpoints.cloud_sql]
}

resource "google_compute_region_target_tcp_proxy" "cloud_sql" {
  project         = var.project_id
  name            = "${var.name_prefix}-postgres-tcp-proxy"
  region          = var.region
  backend_service = google_compute_region_backend_service.cloud_sql.id
}

resource "google_compute_address" "cloud_sql_ilb" {
  project      = var.project_id
  name         = "${var.name_prefix}-postgres-ilb"
  region       = var.region
  subnetwork   = google_compute_subnetwork.cloud_sql.id
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
}

resource "google_compute_forwarding_rule" "cloud_sql" {
  project               = var.project_id
  name                  = "${var.name_prefix}-postgres-ilb"
  region                = var.region
  load_balancing_scheme = "INTERNAL_MANAGED"
  target                = google_compute_region_target_tcp_proxy.cloud_sql.id
  ip_address            = google_compute_address.cloud_sql_ilb.address
  ip_protocol           = "TCP"
  port_range            = "5432"
  network               = google_compute_network.cloud_sql.id
  subnetwork            = google_compute_subnetwork.cloud_sql.id
  allow_global_access   = true

  depends_on = [google_compute_subnetwork.proxy_only]
}

resource "google_compute_service_attachment" "cloud_sql" {
  project               = var.project_id
  name                  = "${var.name_prefix}-postgres-psc"
  region                = var.region
  enable_proxy_protocol = false
  connection_preference = "ACCEPT_MANUAL"
  reconcile_connections = true
  target_service        = google_compute_forwarding_rule.cloud_sql.id
  nat_subnets           = [google_compute_subnetwork.psc_nat.id]

  dynamic "consumer_accept_lists" {
    for_each = var.psc_consumer_accept_projects
    content {
      project_id_or_num = consumer_accept_lists.value.project_id
      connection_limit  = consumer_accept_lists.value.connection_limit
    }
  }
}

resource "clickhouse_clickpipes_reverse_private_endpoint" "cloud_sql" {
  service_id             = var.clickhouse_service_id
  description            = var.rpe_description
  type                   = "GCP_PSC_SERVICE_ATTACHMENT"
  gcp_service_attachment = google_compute_service_attachment.cloud_sql.id

  custom_private_dns_mappings = [
    {
      private_dns_name = local.db_host
    }
  ]
}

resource "clickhouse_clickpipe" "cloud_sql" {
  count = var.create_clickpipe ? 1 : 0

  name       = var.clickpipe_name
  service_id = var.clickhouse_service_id

  depends_on = [clickhouse_clickpipes_reverse_private_endpoint.cloud_sql]

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
