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

module "confluent_serverless" {
  source = "../../modules/confluent-serverless"

  clickhouse_service_id   = var.clickhouse_service_id
  region                  = var.region
  topic_name              = var.topic_name
  access_point_dns_domain = var.access_point_dns_domain
  create_clickpipe        = var.create_clickpipe
  consumer_group          = var.consumer_group
  destination_table       = var.destination_table
  columns                 = var.columns
  sorting_key             = var.sorting_key
}

output "gateway_service_attachment" {
  value = module.confluent_serverless.gateway_service_attachment
}

output "access_point_dns_domain" {
  value = module.confluent_serverless.access_point_dns_domain
}

output "reverse_private_endpoint_ids" {
  value = module.confluent_serverless.reverse_private_endpoint_ids
}

output "clickpipe_id" {
  value = module.confluent_serverless.clickpipe_id
}
