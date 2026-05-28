resource "confluent_environment" "main" {
  display_name = var.environment_display_name
}

resource "confluent_gateway" "serverless" {
  display_name = "${var.resource_prefix}-ingress-psc"

  environment {
    id = confluent_environment.main.id
  }

  gcp_ingress_private_service_connect_gateway {
    region = var.region
  }
}

resource "confluent_kafka_cluster" "serverless" {
  display_name = var.resource_prefix
  availability = var.cluster_availability
  cloud        = "GCP"
  region       = var.region

  enterprise {}

  environment {
    id = confluent_environment.main.id
  }
}

resource "clickhouse_clickpipes_reverse_private_endpoint" "serverless" {
  service_id             = var.clickhouse_service_id
  description            = var.rpe_description
  type                   = "GCP_PSC_SERVICE_ATTACHMENT"
  gcp_service_attachment = confluent_gateway.serverless.gcp_ingress_private_service_connect_gateway[0].private_service_connect_service_attachment

  custom_private_dns_mappings = var.access_point_dns_domain == null ? [] : [
    {
      private_dns_name = "*.${var.access_point_dns_domain}"
    }
  ]
}

resource "confluent_access_point" "serverless" {
  count = var.create_access_point ? 1 : 0

  display_name = "${var.resource_prefix}-ingress-ap"

  environment {
    id = confluent_environment.main.id
  }

  gateway {
    id = confluent_gateway.serverless.id
  }

  gcp_ingress_private_service_connect_endpoint {
    private_service_connect_connection_id = clickhouse_clickpipes_reverse_private_endpoint.serverless.endpoint_id
  }
}

data "confluent_kafka_cluster" "serverless_with_access_point" {
  count = var.create_access_point ? 1 : 0

  id = confluent_kafka_cluster.serverless.id

  environment {
    id = confluent_environment.main.id
  }

  depends_on = [confluent_access_point.serverless]
}

resource "confluent_service_account" "clickpipes" {
  display_name = "${var.resource_prefix}-clickpipes"
  description  = "Service account used by ClickPipes for ${var.resource_prefix}."
}

resource "confluent_role_binding" "clickpipes_admin" {
  principal   = "User:${confluent_service_account.clickpipes.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.serverless.rbac_crn
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
    id          = confluent_kafka_cluster.serverless.id
    api_version = confluent_kafka_cluster.serverless.api_version
    kind        = confluent_kafka_cluster.serverless.kind

    environment {
      id = confluent_environment.main.id
    }
  }

  depends_on = [confluent_role_binding.clickpipes_admin]
}

locals {
  access_point_dns_domain = try(confluent_access_point.serverless[0].gcp_ingress_private_service_connect_endpoint[0].dns_domain, null)
  access_point_bootstrap_endpoints = var.create_access_point ? [
    for endpoint in data.confluent_kafka_cluster.serverless_with_access_point[0].endpoints :
    endpoint.bootstrap_endpoint
    if endpoint.access_point_id == confluent_access_point.serverless[0].id
  ] : []
  bootstrap_endpoint = length(local.access_point_bootstrap_endpoints) > 0 ? local.access_point_bootstrap_endpoints[0] : confluent_kafka_cluster.serverless.bootstrap_endpoint
  bootstrap_address  = replace(local.bootstrap_endpoint, "SASL_SSL://", "")
}

resource "clickhouse_clickpipe" "serverless" {
  count = var.create_clickpipe ? 1 : 0

  name       = var.clickpipe_name
  service_id = var.clickhouse_service_id

  depends_on = [
    clickhouse_clickpipes_reverse_private_endpoint.serverless,
    confluent_access_point.serverless,
  ]

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

      reverse_private_endpoint_ids = [clickhouse_clickpipes_reverse_private_endpoint.serverless.id]
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
      condition     = !var.create_clickpipe || (var.destination_table != null && var.consumer_group != null && length(var.columns) > 0 && var.access_point_dns_domain != null)
      error_message = "destination_table, consumer_group, columns, and access_point_dns_domain must be set when create_clickpipe is true."
    }
  }
}
