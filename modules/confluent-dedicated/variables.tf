variable "clickhouse_service_id" {
  description = "Existing ClickHouse Cloud service ID that will own the RPEs and ClickPipe."
  type        = string
}

variable "cloud" {
  description = "Cloud provider for Confluent Cloud Dedicated private networking. Supported values: AWS, GCP."
  type        = string

  validation {
    condition     = contains(["AWS", "GCP"], upper(var.cloud))
    error_message = "cloud must be AWS or GCP."
  }
}

variable "clickpipes_consumer_aws_account_id" {
  description = "AWS account ID used by the ClickPipes consumer VPC for this ClickHouse service. Required when cloud is AWS."
  type        = string
  default     = null
}

variable "clickpipes_consumer_gcp_project_id" {
  description = "GCP project ID or number used by the ClickPipes consumer VPC for this ClickHouse service. Required when cloud is GCP."
  type        = string
  default     = null
}

variable "region" {
  description = "Cloud region for Confluent Cloud and the ClickHouse service."
  type        = string
}

variable "resource_prefix" {
  description = "Prefix for Confluent resource display names."
  type        = string
  default     = "clickpipes-confluent-dedicated"
}

variable "environment_display_name" {
  description = "Confluent environment display name."
  type        = string
  default     = "clickpipes-confluent-dedicated"
}

variable "network_zones" {
  description = "Cloud provider zones for the Confluent Dedicated private network. AWS values are AZ IDs, for example euc1-az1. GCP values are zones, for example us-central1-a."
  type        = list(string)
}

variable "cluster_availability" {
  description = "Confluent Dedicated cluster availability. Defaults to MULTI_ZONE for AWS and SINGLE_ZONE for GCP."
  type        = string
  default     = null
}

variable "cluster_cku" {
  description = "Confluent Dedicated CKUs. Defaults to 2 for AWS and 1 for GCP."
  type        = number
  default     = null
}

variable "rpe_description" {
  description = "Description for the ClickPipes Reverse Private Endpoint. For GCP, the zone is appended."
  type        = string
  default     = null
}

variable "create_clickpipe" {
  description = "When false, create source infrastructure and RPE connectivity only. When true, create the ClickPipe and start data loading. The module does not produce Kafka records."
  type        = bool
  default     = false
}

variable "clickpipe_name" {
  description = "Name of the ClickPipe to create when create_clickpipe is true."
  type        = string
  default     = "Confluent Cloud Dedicated private networking"
}

variable "topic_name" {
  description = "Kafka topic name used by the ClickPipe. The module does not create or seed the topic."
  type        = string
}

variable "consumer_group" {
  description = "Kafka consumer group for the ClickPipe. Required when create_clickpipe is true."
  type        = string
  default     = null
}

variable "destination_database" {
  description = "Destination ClickHouse database for the ClickPipe."
  type        = string
  default     = "default"
}

variable "destination_table" {
  description = "Destination ClickHouse table for the Kafka ClickPipe. Required when create_clickpipe is true."
  type        = string
  default     = null
}

variable "kafka_format" {
  description = "Kafka message format."
  type        = string
  default     = "JSONEachRow"
}

variable "offset_strategy" {
  description = "Kafka offset strategy."
  type        = string
  default     = "from_beginning"
}

variable "columns" {
  description = "Destination table columns and field mappings for the Kafka ClickPipe. Required when create_clickpipe is true."
  type = list(object({
    name = string
    type = string
  }))
  default = []
}

variable "sorting_key" {
  description = "Sorting key for the managed ClickHouse destination table."
  type        = list(string)
  default     = []
}
