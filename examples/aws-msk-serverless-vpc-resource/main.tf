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

module "aws_msk_serverless_vpc_resource" {
  source = "../../modules/aws-msk-serverless-vpc-resource"

  clickhouse_service_id              = var.clickhouse_service_id
  clickhouse_service_iam_role        = var.clickhouse_service_iam_role
  clickpipes_consumer_aws_account_id = var.clickpipes_consumer_aws_account_id
  region                             = var.region
  resource_prefix                    = var.resource_prefix
  az_count                           = var.az_count
  vpc_cidr                           = var.vpc_cidr
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
  value = module.aws_msk_serverless_vpc_resource.bootstrap_endpoint
}

output "broker_wildcard_private_dns" {
  value = module.aws_msk_serverless_vpc_resource.broker_wildcard_private_dns
}

output "vpc_resource_configuration_arn" {
  value = module.aws_msk_serverless_vpc_resource.vpc_resource_configuration_arn
}

output "vpc_resource_share_arn" {
  value = module.aws_msk_serverless_vpc_resource.vpc_resource_share_arn
}

output "clickpipe_msk_reader_role_arn" {
  value = module.aws_msk_serverless_vpc_resource.clickpipe_msk_reader_role_arn
}

output "reverse_private_endpoint_ids" {
  value = module.aws_msk_serverless_vpc_resource.reverse_private_endpoint_ids
}

output "clickpipe_id" {
  value = module.aws_msk_serverless_vpc_resource.clickpipe_id
}
