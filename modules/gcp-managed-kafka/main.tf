resource "google_project_service" "managedkafka" {
  project = var.project_id
  service = "managedkafka.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "compute" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "dns" {
  project = var.project_id
  service = "dns.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "iam" {
  project = var.project_id
  service = "iam.googleapis.com"

  disable_on_destroy = false
}

data "google_compute_zones" "available" {
  project = var.project_id
  region  = var.region
}

locals {
  kafka_dns_zone    = "${var.name_prefix}.${var.region}.managedkafka.${var.project_id}.cloud.goog"
  kafka_broker_keys = toset([for i in range(var.kafka_vcpu_count) : "broker-${i}"])

  broker_addresses = [
    for addr in data.google_compute_addresses.kafka_all.addresses :
    addr if can(regex("^gmk-.*broker-\\d+$", addr.name))
  ]

  broker_ip_by_key = {
    for addr in local.broker_addresses :
    "broker-${regex("broker-(\\d+)$", addr.name)[0]}" => addr.address
  }

  sorted_broker_keys = sort(tolist(local.kafka_broker_keys))
}

resource "google_compute_network" "kafka" {
  project                 = var.project_id
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "kafka" {
  project       = var.project_id
  name          = "${var.name_prefix}-subnet"
  region        = var.region
  network       = google_compute_network.kafka.id
  ip_cidr_range = var.subnet_cidr
}

resource "google_compute_subnetwork" "psc_nat" {
  for_each = var.psc_nat_subnet_cidrs

  project       = var.project_id
  name          = "${var.name_prefix}-psc-nat-${each.key}"
  region        = var.region
  network       = google_compute_network.kafka.id
  ip_cidr_range = each.value
  purpose       = "PRIVATE_SERVICE_CONNECT"
}

resource "google_compute_firewall" "allow_internal" {
  project = var.project_id
  name    = "${var.name_prefix}-allow-internal"
  network = google_compute_network.kafka.id

  allow {
    protocol = "tcp"
    ports    = ["9092"]
  }

  source_ranges = concat(
    [var.subnet_cidr, var.proxy_only_subnet_cidr],
    values(var.psc_nat_subnet_cidrs)
  )
}

resource "google_compute_firewall" "allow_health_check" {
  project = var.project_id
  name    = "${var.name_prefix}-allow-health-check"
  network = google_compute_network.kafka.id

  allow {
    protocol = "tcp"
    ports    = ["9092"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
}

resource "google_managed_kafka_cluster" "kafka" {
  project    = var.project_id
  cluster_id = var.name_prefix
  location   = var.region

  capacity_config {
    vcpu_count   = var.kafka_vcpu_count
    memory_bytes = var.kafka_memory_bytes
  }

  gcp_config {
    access_config {
      network_configs {
        subnet = google_compute_subnetwork.kafka.id
      }
    }
  }

  rebalance_config {
    mode = "AUTO_REBALANCE_ON_SCALE_UP"
  }

  depends_on = [google_project_service.managedkafka]

  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }
}

resource "google_managed_kafka_topic" "topic" {
  count = var.create_topic ? 1 : 0

  project            = var.project_id
  cluster            = google_managed_kafka_cluster.kafka.cluster_id
  location           = var.region
  topic_id           = var.topic_name
  partition_count    = var.topic_partitions
  replication_factor = var.topic_replication_factor
  configs            = { "cleanup.policy" = "delete" }
}

resource "google_service_account" "kafka_client" {
  project      = var.project_id
  account_id   = "${substr(var.name_prefix, 0, 23)}-client"
  display_name = "Kafka client for ${var.name_prefix}"

  depends_on = [google_project_service.iam]
}

resource "google_project_iam_member" "kafka_client" {
  project = var.project_id
  role    = "roles/managedkafka.client"
  member  = "serviceAccount:${google_service_account.kafka_client.email}"
}

resource "google_service_account_key" "kafka_client" {
  service_account_id = google_service_account.kafka_client.name
}

data "google_compute_addresses" "kafka_all" {
  project = var.project_id
  region  = var.region
  filter  = "subnetwork = \"${google_compute_subnetwork.kafka.self_link}\""

  depends_on = [google_managed_kafka_cluster.kafka]
}

resource "google_compute_subnetwork" "proxy_only" {
  project       = var.project_id
  name          = "${var.name_prefix}-proxy-only"
  region        = var.region
  network       = google_compute_network.kafka.id
  ip_cidr_range = var.proxy_only_subnet_cidr
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

resource "google_compute_region_health_check" "kafka" {
  project = var.project_id
  name    = "${var.name_prefix}-kafka-hc"
  region  = var.region

  tcp_health_check {
    port = 9092
  }

  check_interval_sec  = 30
  timeout_sec         = 10
  healthy_threshold   = 1
  unhealthy_threshold = 10
}

resource "google_compute_network_endpoint_group" "kafka" {
  for_each = local.kafka_broker_keys

  project               = var.project_id
  name                  = "${var.name_prefix}-${each.key}-neg"
  network               = google_compute_network.kafka.id
  network_endpoint_type = "NON_GCP_PRIVATE_IP_PORT"
  default_port          = 9092
  zone                  = data.google_compute_zones.available.names[0]
}

resource "google_compute_network_endpoints" "kafka" {
  for_each = local.kafka_broker_keys

  project                = var.project_id
  zone                   = data.google_compute_zones.available.names[0]
  network_endpoint_group = google_compute_network_endpoint_group.kafka[each.key].name

  network_endpoints {
    ip_address = local.broker_ip_by_key[each.key]
    port       = 9092
  }
}

resource "google_compute_region_backend_service" "kafka" {
  for_each = local.kafka_broker_keys

  project               = var.project_id
  name                  = "${var.name_prefix}-${each.key}-bs"
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  health_checks         = [google_compute_region_health_check.kafka.id]

  backend {
    group                        = google_compute_network_endpoint_group.kafka[each.key].id
    balancing_mode               = "CONNECTION"
    max_connections_per_endpoint = 1000
    capacity_scaler              = 1.0
  }
}

resource "google_compute_region_target_tcp_proxy" "kafka" {
  for_each = local.kafka_broker_keys

  project         = var.project_id
  name            = "${var.name_prefix}-${each.key}-tcp-proxy"
  region          = var.region
  backend_service = google_compute_region_backend_service.kafka[each.key].id
}

resource "google_compute_address" "kafka" {
  for_each = local.kafka_broker_keys

  project      = var.project_id
  name         = "${var.name_prefix}-${each.key}-ilb"
  region       = var.region
  subnetwork   = google_compute_subnetwork.kafka.id
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
}

resource "google_compute_forwarding_rule" "kafka" {
  for_each = local.kafka_broker_keys

  project               = var.project_id
  name                  = "${var.name_prefix}-${each.key}-ilb"
  region                = var.region
  load_balancing_scheme = "INTERNAL_MANAGED"
  target                = google_compute_region_target_tcp_proxy.kafka[each.key].id
  ip_address            = google_compute_address.kafka[each.key].address
  ip_protocol           = "TCP"
  port_range            = "9092"
  network               = google_compute_network.kafka.id
  subnetwork            = google_compute_subnetwork.kafka.id
  allow_global_access   = true

  depends_on = [google_compute_subnetwork.proxy_only]
}

resource "google_compute_service_attachment" "kafka" {
  for_each = local.kafka_broker_keys

  project               = var.project_id
  name                  = "${var.name_prefix}-${each.key}-psc"
  region                = var.region
  enable_proxy_protocol = false
  connection_preference = "ACCEPT_MANUAL"
  reconcile_connections = true
  target_service        = google_compute_forwarding_rule.kafka[each.key].id
  nat_subnets           = [google_compute_subnetwork.psc_nat[each.key].id]

  dynamic "consumer_accept_lists" {
    for_each = var.psc_consumer_accept_projects
    content {
      project_id_or_num = consumer_accept_lists.value.project_id
      connection_limit  = consumer_accept_lists.value.connection_limit
    }
  }
}

resource "clickhouse_clickpipes_reverse_private_endpoint" "kafka" {
  for_each = local.kafka_broker_keys

  service_id             = var.clickhouse_service_id
  description            = "${var.rpe_description_prefix} ${each.key}"
  type                   = "GCP_PSC_SERVICE_ATTACHMENT"
  gcp_service_attachment = google_compute_service_attachment.kafka[each.key].id
}

resource "clickhouse_clickpipes_reverse_private_endpoint_custom_private_dns" "kafka" {
  for_each = local.kafka_broker_keys

  service_id                  = var.clickhouse_service_id
  reverse_private_endpoint_id = clickhouse_clickpipes_reverse_private_endpoint.kafka[each.key].id

  mapping = concat(
    [
      {
        private_dns_name = "${each.key}.${local.kafka_dns_zone}"
      }
    ],
    each.key == local.sorted_broker_keys[0] ? [
      {
        private_dns_name = "bootstrap.${local.kafka_dns_zone}"
      }
    ] : []
  )
}

resource "clickhouse_clickpipe" "kafka" {
  count = var.create_clickpipe ? 1 : 0

  name       = var.clickpipe_name
  service_id = var.clickhouse_service_id

  depends_on = [clickhouse_clickpipes_reverse_private_endpoint_custom_private_dns.kafka]

  scaling = {
    replicas = 1
  }

  source = {
    kafka = {
      type           = "gcmk"
      format         = var.kafka_format
      brokers        = "bootstrap.${local.kafka_dns_zone}:9092"
      topics         = var.topic_name
      consumer_group = var.consumer_group
      authentication = "PLAIN"

      credentials = {
        username = google_service_account.kafka_client.email
        password = google_service_account_key.kafka_client.private_key
      }

      offset = {
        strategy = var.offset_strategy
      }

      reverse_private_endpoint_ids = [
        for key in local.sorted_broker_keys : clickhouse_clickpipes_reverse_private_endpoint.kafka[key].id
      ]
    }
  }

  destination = {
    database      = var.destination_database
    table         = var.destination_table
    managed_table = true

    table_definition = {
      engine = {
        type = "MergeTree"
      }
      sorting_key = var.sorting_key
    }

    columns = var.columns
  }

  field_mappings = [
    for column in var.columns : {
      source_field      = column.name
      destination_field = column.name
    }
  ]

  lifecycle {
    precondition {
      condition     = !var.create_clickpipe || (var.destination_table != null && var.consumer_group != null && length(var.columns) > 0)
      error_message = "destination_table, consumer_group, and columns must be set when create_clickpipe is true."
    }
  }
}
