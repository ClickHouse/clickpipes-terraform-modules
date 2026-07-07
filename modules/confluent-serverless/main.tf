resource "confluent_environment" "main" {
  display_name = var.environment_display_name
}

resource "confluent_gateway" "serverless" {
  display_name = "${var.resource_prefix}-ingress"

  environment {
    id = confluent_environment.main.id
  }

  dynamic "aws_ingress_private_link_gateway" {
    for_each = local.is_aws ? [1] : []

    content {
      region = var.region
    }
  }

  dynamic "gcp_ingress_private_service_connect_gateway" {
    for_each = local.is_gcp ? [1] : []

    content {
      region = var.region
    }
  }
}

resource "confluent_kafka_cluster" "serverless" {
  display_name = var.resource_prefix
  availability = var.cluster_availability
  cloud        = local.cloud
  region       = var.region

  enterprise {
    max_ecku = var.max_ecku
  }

  environment {
    id = confluent_environment.main.id
  }
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
  cloud           = upper(var.cloud)
  cloud_dns_label = lower(var.cloud)
  is_aws          = local.cloud == "AWS"
  is_gcp          = local.cloud == "GCP"

  aws_vpc_endpoint_service_name = local.is_aws ? confluent_gateway.serverless.aws_ingress_private_link_gateway[0].vpc_endpoint_service_name : null
  gcp_service_attachment        = local.is_gcp ? confluent_gateway.serverless.gcp_ingress_private_service_connect_gateway[0].private_service_connect_service_attachment : null

  access_point_dns_domain = local.is_aws ? confluent_access_point.serverless.aws_ingress_private_link_endpoint[0].dns_domain : confluent_access_point.serverless.gcp_ingress_private_service_connect_endpoint[0].dns_domain
  glb_dns_domain          = "${var.region}.${local.cloud_dns_label}.accesspoint.glb.confluent.cloud"

  custom_private_dns_mappings = [
    {
      // Maps public GLB hostname to the RPE for ClickPipes DNS compatibility. See README for more details
      private_dns_name = "*.${local.glb_dns_domain}"
    },
    {
      private_dns_name = "*.${local.access_point_dns_domain}"
    },
  ]
}

resource "clickhouse_clickpipes_reverse_private_endpoint" "serverless" {
  service_id                = var.clickhouse_service_id
  description               = var.rpe_description
  type                      = local.is_aws ? "VPC_ENDPOINT_SERVICE" : "GCP_PSC_SERVICE_ATTACHMENT"
  vpc_endpoint_service_name = local.aws_vpc_endpoint_service_name
  gcp_service_attachment    = local.gcp_service_attachment
}

resource "confluent_access_point" "serverless" {
  display_name = "${var.resource_prefix}-ingress-ap"

  environment {
    id = confluent_environment.main.id
  }

  gateway {
    id = confluent_gateway.serverless.id
  }

  dynamic "aws_ingress_private_link_endpoint" {
    for_each = local.is_aws ? [1] : []

    content {
      vpc_endpoint_id = clickhouse_clickpipes_reverse_private_endpoint.serverless.endpoint_id
    }
  }

  dynamic "gcp_ingress_private_service_connect_endpoint" {
    for_each = local.is_gcp ? [1] : []

    content {
      private_service_connect_connection_id = clickhouse_clickpipes_reverse_private_endpoint.serverless.endpoint_id
    }
  }
}

resource "clickhouse_clickpipes_reverse_private_endpoint_custom_private_dns" "serverless" {
  service_id                  = var.clickhouse_service_id
  reverse_private_endpoint_id = clickhouse_clickpipes_reverse_private_endpoint.serverless.id
  mapping                     = local.custom_private_dns_mappings

  depends_on = [confluent_access_point.serverless]
}

data "confluent_kafka_cluster" "serverless_with_access_point" {
  id = confluent_kafka_cluster.serverless.id

  environment {
    id = confluent_environment.main.id
  }

  depends_on = [confluent_access_point.serverless]
}

locals {
  access_point_bootstrap_endpoints = [
    for endpoint in data.confluent_kafka_cluster.serverless_with_access_point.endpoints :
    endpoint.bootstrap_endpoint
    if endpoint.access_point_id == confluent_access_point.serverless.id
  ]

  bootstrap_endpoint = length(local.access_point_bootstrap_endpoints) > 0 ? local.access_point_bootstrap_endpoints[0] : confluent_kafka_cluster.serverless.bootstrap_endpoint
  bootstrap_address  = replace(local.bootstrap_endpoint, "SASL_SSL://", "")
}

resource "clickhouse_clickpipe" "serverless" {
  count = var.create_clickpipe ? 1 : 0

  name       = var.clickpipe_name
  service_id = var.clickhouse_service_id

  depends_on = [clickhouse_clickpipes_reverse_private_endpoint_custom_private_dns.serverless]

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
      condition     = !var.create_clickpipe || (var.destination_table != null && var.consumer_group != null && length(var.columns) > 0)
      error_message = "destination_table, consumer_group, and columns must be set when create_clickpipe is true."
    }
  }
}
