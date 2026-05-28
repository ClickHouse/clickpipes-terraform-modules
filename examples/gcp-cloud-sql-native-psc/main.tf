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

module "cloud_sql_native_psc" {
  source = "../../modules/gcp-cloud-sql-native-psc"

  project_id                    = var.gcp_project_id
  region                        = var.region
  name_prefix                   = var.name_prefix
  clickhouse_service_id         = var.clickhouse_service_id
  psc_allowed_consumer_projects = var.psc_allowed_consumer_projects
  create_clickpipe              = var.create_clickpipe
  source_table                  = var.source_table
  target_table                  = var.target_table
}

output "cloud_sql_dns_name" {
  value = module.cloud_sql_native_psc.cloud_sql_dns_name
}

output "reverse_private_endpoint_ids" {
  value = module.cloud_sql_native_psc.reverse_private_endpoint_ids
}

output "clickpipe_id" {
  value = module.cloud_sql_native_psc.clickpipe_id
}
