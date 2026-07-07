terraform {
  required_version = ">= 1.4.0"

  required_providers {
    clickhouse = {
      source  = "ClickHouse/clickhouse"
      version = ">= 3.16.0"
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

module "cloud_sql_private_network_psc" {
  source = "../../modules/gcp-cloud-sql-private-network-psc"

  project_id                   = var.gcp_project_id
  region                       = var.region
  name_prefix                  = var.name_prefix
  clickhouse_service_id        = var.clickhouse_service_id
  psc_consumer_accept_projects = var.psc_consumer_accept_projects
  create_clickpipe             = var.create_clickpipe
  source_table                 = var.source_table
  target_table                 = var.target_table
}

output "database_host" {
  value = module.cloud_sql_private_network_psc.database_host
}

output "reverse_private_endpoint_ids" {
  value = module.cloud_sql_private_network_psc.reverse_private_endpoint_ids
}

output "clickpipe_id" {
  value = module.cloud_sql_private_network_psc.clickpipe_id
}
