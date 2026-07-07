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

module "aws_confluent_dedicated" {
  source = "../../modules/aws-confluent-dedicated"

  clickhouse_service_id              = var.clickhouse_service_id
  clickpipes_consumer_aws_account_id = var.clickpipes_consumer_aws_account_id
  region                             = var.region
  network_zones                      = var.network_zones
  topic_name                         = var.topic_name
  create_clickpipe                   = var.create_clickpipe
  consumer_group                     = var.consumer_group
  destination_table                  = var.destination_table
  columns                            = var.columns
  sorting_key                        = var.sorting_key
}

output "vpc_endpoint_service_name" {
  value = module.aws_confluent_dedicated.vpc_endpoint_service_name
}

output "dns_domain" {
  value = module.aws_confluent_dedicated.dns_domain
}

output "reverse_private_endpoint_ids" {
  value = module.aws_confluent_dedicated.reverse_private_endpoint_ids
}

output "clickpipe_id" {
  value = module.aws_confluent_dedicated.clickpipe_id
}
