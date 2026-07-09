terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
    clickhouse = {
      source  = "ClickHouse/clickhouse"
      version = ">= 3.17.0"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "clickhouse" {
  organization_id = var.clickhouse_organization_id
  token_key       = var.clickhouse_cloud_api_key
  token_secret    = var.clickhouse_cloud_api_secret
}

module "aws_msk_vpc_endpoint_service" {
  source = "../../modules/aws-msk-vpc-endpoint-service"

  clickhouse_service_id              = var.clickhouse_service_id
  clickhouse_service_iam_role        = var.clickhouse_service_iam_role
  clickpipes_consumer_aws_account_id = var.clickpipes_consumer_aws_account_id
  region                             = var.region
  supported_regions                  = var.supported_regions
  resource_prefix                    = var.resource_prefix
  az_count                           = var.az_count
  vpc_cidr                           = var.vpc_cidr
  kafka_version                      = var.kafka_version
  broker_instance_type               = var.broker_instance_type
  number_of_broker_nodes             = var.number_of_broker_nodes
  topic_name                         = var.topic_name
  create_clickpipe                   = var.create_clickpipe
  clickpipe_name                     = var.clickpipe_name
  consumer_group                     = var.consumer_group
  destination_table                  = var.destination_table
  columns                            = var.columns
  sorting_key                        = var.sorting_key
  tags                               = var.tags
}

output "bootstrap_endpoint" {
  value = module.aws_msk_vpc_endpoint_service.bootstrap_endpoint
}

output "broker_hosts" {
  value = module.aws_msk_vpc_endpoint_service.broker_hosts
}

output "vpc_endpoint_service_names" {
  value = module.aws_msk_vpc_endpoint_service.vpc_endpoint_service_names
}

output "reverse_private_endpoint_ids" {
  value = module.aws_msk_vpc_endpoint_service.reverse_private_endpoint_ids
}

output "clickpipe_msk_reader_role_arn" {
  value = module.aws_msk_vpc_endpoint_service.clickpipe_msk_reader_role_arn
}

output "clickpipe_id" {
  value = module.aws_msk_vpc_endpoint_service.clickpipe_id
}
