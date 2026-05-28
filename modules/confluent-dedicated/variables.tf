variable "clickhouse_service_id" {
  description = "Existing ClickHouse Cloud service ID that will own the RPEs and ClickPipe."
  type        = string
}

variable "clickpipes_consumer_project_id" {
  description = "GCP project ID or number used by the ClickPipes consumer VPC for this ClickHouse service."
  type        = string
}

variable "region" {
  description = "GCP region for Confluent Cloud and the ClickHouse service."
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
  description = "GCP zones for the Confluent Dedicated PSC network."
  type        = list(string)
}

variable "cluster_availability" {
  description = "Confluent Dedicated cluster availability."
  type        = string
  default     = "SINGLE_ZONE"
}

variable "cluster_cku" {
  description = "Confluent Dedicated CKUs."
  type        = number
  default     = 1
}

variable "rpe_description_prefix" {
  description = "Description prefix for Confluent Dedicated RPEs."
  type        = string
  default     = "Confluent Cloud Dedicated PSC endpoint"
}

variable "create_clickpipe" {
  description = "When false, create source infrastructure and RPE connectivity only. When true, create the ClickPipe and start data loading. The module does not produce Kafka records."
  type        = bool
  default     = false
}

variable "clickpipe_name" {
  description = "Name of the ClickPipe to create when create_clickpipe is true."
  type        = string
  default     = "Confluent Cloud Dedicated PSC"
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
