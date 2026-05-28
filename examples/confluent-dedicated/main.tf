terraform {
  required_version = ">= 1.4.0"

  required_providers {
    clickhouse = {
      source  = "ClickHouse/clickhouse"
      version = ">= 3.14.0"
    }
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.73.0"
    }
  }
}

provider "clickhouse" {
  organization_id = var.clickhouse_organization_id
  token_key       = var.clickhouse_cloud_api_key
  token_secret    = var.clickhouse_cloud_api_secret
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

module "confluent_dedicated" {
  source = "../../modules/confluent-dedicated"

  clickhouse_service_id          = var.clickhouse_service_id
  clickpipes_consumer_project_id = var.clickpipes_consumer_project_id
  region                         = var.region
  network_zones                  = var.network_zones
  topic_name                     = var.topic_name
  create_clickpipe               = var.create_clickpipe
  consumer_group                 = var.consumer_group
  destination_table              = var.destination_table
  columns                        = var.columns
  sorting_key                    = var.sorting_key
}

output "bootstrap_endpoint" {
  value = module.confluent_dedicated.bootstrap_endpoint
}

output "reverse_private_endpoint_ids" {
  value = module.confluent_dedicated.reverse_private_endpoint_ids
}

output "clickpipe_id" {
  value = module.confluent_dedicated.clickpipe_id
}
