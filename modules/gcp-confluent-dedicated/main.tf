resource "confluent_environment" "main" {
  display_name = var.environment_display_name
}

resource "confluent_network" "dedicated" {
  display_name     = "${var.resource_prefix}-psc"
  cloud            = "GCP"
  region           = var.region
  connection_types = ["PRIVATELINK"]
  zones            = var.network_zones

  environment {
    id = confluent_environment.main.id
  }

  dns_config {
    resolution = "PRIVATE"
  }
}

resource "confluent_private_link_access" "dedicated" {
  display_name = "${var.resource_prefix}-psc-access"

  gcp {
    project = var.clickpipes_consumer_project_id
  }

  environment {
    id = confluent_environment.main.id
  }

  network {
    id = confluent_network.dedicated.id
  }
}

resource "confluent_kafka_cluster" "dedicated" {
  display_name = var.resource_prefix
  availability = var.cluster_availability
  cloud        = "GCP"
  region       = var.region

  dedicated {
    cku = var.cluster_cku
  }

  environment {
    id = confluent_environment.main.id
  }

  network {
    id = confluent_network.dedicated.id
  }
}

resource "confluent_service_account" "clickpipes" {
  display_name = "${var.resource_prefix}-clickpipes"
  description  = "Service account used by ClickPipes for ${var.resource_prefix}."
}

resource "confluent_role_binding" "clickpipes_admin" {
  principal   = "User:${confluent_service_account.clickpipes.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.dedicated.rbac_crn
}

resource "confluent_api_key" "clickpipes" {
  display_name           = "${var.resource_prefix}-clickpipes-key"
  description            = "Kafka API key used by ClickPipes for ${var.resource_prefix}."
  disable_wait_for_ready = true

  owner {
    id          = confluent_service_account.clickpipes.id
    api_version = confluent_service_account.clickpipes.api_version
    kind        = confluent_service_account.clickpipes.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.dedicated.id
    api_version = confluent_kafka_cluster.dedicated.api_version
    kind        = confluent_kafka_cluster.dedicated.kind

    environment {
      id = confluent_environment.main.id
    }
  }

  depends_on = [confluent_role_binding.clickpipes_admin]
}

locals {
  sorted_zones      = sort(var.network_zones)
  bootstrap_address = replace(confluent_kafka_cluster.dedicated.bootstrap_endpoint, "SASL_SSL://", "")
  dns_domain        = confluent_network.dedicated.dns_domain
}

resource "clickhouse_clickpipes_reverse_private_endpoint" "dedicated" {
  for_each = toset(var.network_zones)

  service_id             = var.clickhouse_service_id
  description            = "${var.rpe_description_prefix} ${each.key}"
  type                   = "GCP_PSC_SERVICE_ATTACHMENT"
  gcp_service_attachment = confluent_network.dedicated.gcp[0].private_service_connect_service_attachments[each.key]

  depends_on = [confluent_private_link_access.dedicated]
}

resource "clickhouse_clickpipes_reverse_private_endpoint_custom_private_dns" "dedicated" {
  for_each = toset(var.network_zones)

  service_id                  = var.clickhouse_service_id
  reverse_private_endpoint_id = clickhouse_clickpipes_reverse_private_endpoint.dedicated[each.key].id

  mapping = concat(
    [
      {
        private_dns_name = "*.${each.key}.${local.dns_domain}"
      }
    ],
    each.key == local.sorted_zones[0] ? [
      {
        private_dns_name = "*.${local.dns_domain}"
      }
    ] : []
  )
}

resource "clickhouse_clickpipe" "dedicated" {
  count = var.create_clickpipe ? 1 : 0

  name       = var.clickpipe_name
  service_id = var.clickhouse_service_id

  depends_on = [clickhouse_clickpipes_reverse_private_endpoint_custom_private_dns.dedicated]

  scaling = {
    replicas = 1
  }

  source = {
    kafka = {
      type           = "confluent"
      format         = var.kafka_format
      brokers        = local.bootstrap_address
      topics         = var.topic_name
      consumer_group = var.consumer_group
      authentication = "PLAIN"

      credentials = {
        username = confluent_api_key.clickpipes.id
        password = confluent_api_key.clickpipes.secret
      }

      offset = {
        strategy = var.offset_strategy
      }

      reverse_private_endpoint_ids = [
        for zone in local.sorted_zones : clickhouse_clickpipes_reverse_private_endpoint.dedicated[zone].id
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
