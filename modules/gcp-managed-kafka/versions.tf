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
