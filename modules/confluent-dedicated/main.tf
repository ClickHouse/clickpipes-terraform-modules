resource "confluent_environment" "main" {
  display_name = var.environment_display_name
}

resource "confluent_network" "dedicated" {
  display_name     = "${var.resource_prefix}-${local.network_suffix}"
  cloud            = local.cloud
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
  display_name = "${var.resource_prefix}-${local.network_suffix}-access"

  dynamic "aws" {
    for_each = local.is_aws ? [1] : []

    content {
      account = var.clickpipes_consumer_aws_account_id
    }
  }

  dynamic "gcp" {
    for_each = local.is_gcp ? [1] : []

    content {
      project = var.clickpipes_consumer_gcp_project_id
    }
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
  availability = local.cluster_availability
  cloud        = local.cloud
  region       = var.region

  dedicated {
    cku = local.cluster_cku
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
  cloud             = upper(var.cloud)
  is_aws            = local.cloud == "AWS"
  is_gcp            = local.cloud == "GCP"
  sorted_zones      = sort(var.network_zones)
  network_suffix    = local.is_aws ? "privatelink" : "psc"
  bootstrap_address = replace(confluent_kafka_cluster.dedicated.bootstrap_endpoint, "SASL_SSL://", "")
  dns_domain        = confluent_network.dedicated.dns_domain

  cluster_availability = coalesce(var.cluster_availability, local.is_aws ? "MULTI_ZONE" : "SINGLE_ZONE")
  cluster_cku          = coalesce(var.cluster_cku, local.is_aws ? 2 : 1)

  aws_vpc_endpoint_service_name = local.is_aws ? confluent_network.dedicated.aws[0].private_link_endpoint_service : null
  gcp_service_attachments       = local.is_gcp ? confluent_network.dedicated.gcp[0].private_service_connect_service_attachments : {}

  rpe_targets = local.is_aws ? {
    regional = {
      description               = var.rpe_description != null ? var.rpe_description : "Confluent Cloud Dedicated AWS PrivateLink endpoint"
      type                      = "VPC_ENDPOINT_SERVICE"
      vpc_endpoint_service_name = local.aws_vpc_endpoint_service_name
      gcp_service_attachment    = null
    }
    } : {
    for zone in local.sorted_zones : zone => {
      description               = "${var.rpe_description != null ? var.rpe_description : "Confluent Cloud Dedicated PSC endpoint"} ${zone}"
      type                      = "GCP_PSC_SERVICE_ATTACHMENT"
      vpc_endpoint_service_name = null
      gcp_service_attachment    = local.gcp_service_attachments[zone]
    }
  }

  custom_private_dns_mappings = local.is_aws ? {
    regional = concat(
      [
        {
          private_dns_name = "*.${local.dns_domain}"
        }
      ],
      [
        for zone in local.sorted_zones : {
          private_dns_name = "*.${zone}.${local.dns_domain}"
        }
      ]
    )
    } : {
    for zone in local.sorted_zones : zone => concat(
      [
        {
          private_dns_name = "*.${zone}.${local.dns_domain}"
        }
      ],
      zone == local.sorted_zones[0] ? [
        {
          private_dns_name = "*.${local.dns_domain}"
        }
      ] : []
    )
  }
}

resource "clickhouse_clickpipes_reverse_private_endpoint" "dedicated" {
  for_each = local.rpe_targets

  service_id                = var.clickhouse_service_id
  description               = each.value.description
  type                      = each.value.type
  vpc_endpoint_service_name = each.value.vpc_endpoint_service_name
  gcp_service_attachment    = each.value.gcp_service_attachment

  depends_on = [confluent_private_link_access.dedicated]
}

resource "clickhouse_clickpipes_reverse_private_endpoint_custom_private_dns" "dedicated" {
  for_each = local.custom_private_dns_mappings

  service_id                  = var.clickhouse_service_id
  reverse_private_endpoint_id = clickhouse_clickpipes_reverse_private_endpoint.dedicated[each.key].id
  mapping                     = each.value
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
        for key in sort(keys(clickhouse_clickpipes_reverse_private_endpoint.dedicated)) :
        clickhouse_clickpipes_reverse_private_endpoint.dedicated[key].id
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
