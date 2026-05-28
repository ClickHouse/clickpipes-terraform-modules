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
