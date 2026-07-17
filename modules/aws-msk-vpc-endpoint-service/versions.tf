terraform {
  required_version = ">= 1.4.0"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
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
