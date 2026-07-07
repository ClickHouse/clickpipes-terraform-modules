terraform {
  required_version = ">= 1.4.0"

  required_providers {
    clickhouse = {
      source  = "ClickHouse/clickhouse"
      version = ">= 3.16.0"
    }
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.76.0"
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

module "gcp_confluent_serverless" {
  source = "../../modules/confluent-serverless"

  clickhouse_service_id = var.clickhouse_service_id
  cloud                 = "GCP"
  region                = var.region
  topic_name            = var.topic_name
  create_clickpipe      = var.create_clickpipe
  consumer_group        = var.consumer_group
  destination_table     = var.destination_table
  columns               = var.columns
  sorting_key           = var.sorting_key
}

output "gateway_service_attachment" {
  value = module.gcp_confluent_serverless.gateway_service_attachment
}

output "access_point_dns_domain" {
  value = module.gcp_confluent_serverless.access_point_dns_domain
}

output "glb_dns_domain" {
  value = module.gcp_confluent_serverless.glb_dns_domain
}

output "custom_private_dns_mappings" {
  value = module.gcp_confluent_serverless.custom_private_dns_mappings
}

output "bootstrap_endpoint" {
  value = module.gcp_confluent_serverless.bootstrap_endpoint
}

output "reverse_private_endpoint_ids" {
  value = module.gcp_confluent_serverless.reverse_private_endpoint_ids
}

output "clickpipe_id" {
  value = module.gcp_confluent_serverless.clickpipe_id
}
