terraform {
  required_version = ">= 1.4.0"

  required_providers {
    clickhouse = {
      source  = "ClickHouse/clickhouse"
      version = ">= 3.14.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.region
}

provider "clickhouse" {
  organization_id = var.clickhouse_organization_id
  token_key       = var.clickhouse_cloud_api_key
  token_secret    = var.clickhouse_cloud_api_secret
}

module "gcp_managed_kafka" {
  source = "../../modules/gcp-managed-kafka"

  project_id                   = var.gcp_project_id
  region                       = var.region
  name_prefix                  = var.name_prefix
  clickhouse_service_id        = var.clickhouse_service_id
  psc_consumer_accept_projects = var.psc_consumer_accept_projects
  topic_name                   = var.topic_name
  create_topic                 = var.create_topic
  create_clickpipe             = var.create_clickpipe
  consumer_group               = var.consumer_group
  destination_table            = var.destination_table
  columns                      = var.columns
  sorting_key                  = var.sorting_key
}

output "bootstrap_address" {
  value = module.gcp_managed_kafka.bootstrap_address
}

output "reverse_private_endpoint_ids" {
  value = module.gcp_managed_kafka.reverse_private_endpoint_ids
}

output "clickpipe_id" {
  value = module.gcp_managed_kafka.clickpipe_id
}
