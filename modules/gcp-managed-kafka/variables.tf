variable "project_id" {
  description = "GCP project ID where Managed Kafka and PSC producer resources are created."
  type        = string
}

variable "region" {
  description = "GCP region for Managed Kafka, PSC, and the ClickHouse service."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for GCP resource names and the Kafka cluster ID."
  type        = string
  default     = "clickpipes-managed-kafka"
}

variable "clickhouse_service_id" {
  description = "Existing ClickHouse Cloud service ID that will own the RPEs and ClickPipe."
  type        = string
}

variable "kafka_vcpu_count" {
  description = "Number of vCPUs for the Managed Kafka cluster. Managed Kafka creates one broker per vCPU."
  type        = number
  default     = 3
}

variable "kafka_memory_bytes" {
  description = "Memory in bytes for the Managed Kafka cluster."
  type        = number
  default     = 3221225472
}

variable "subnet_cidr" {
  description = "CIDR range for the Managed Kafka subnet."
  type        = string
  default     = "10.0.0.0/24"
}

variable "psc_nat_subnet_cidrs" {
  description = "CIDR ranges for per-broker PSC NAT subnets. Keys must match broker names such as broker-0, broker-1, broker-2."
  type        = map(string)
  default = {
    broker-0 = "10.0.1.0/28"
    broker-1 = "10.0.1.16/28"
    broker-2 = "10.0.1.32/28"
  }
}

variable "proxy_only_subnet_cidr" {
  description = "CIDR range for the regional proxy-only subnet required by INTERNAL_MANAGED TCP load balancing."
  type        = string
  default     = "10.0.2.0/24"
}

variable "psc_consumer_accept_projects" {
  description = "GCP project IDs or numbers auto-accepted on the producer-owned PSC service attachments. Include the ClickPipes consumer project for your ClickHouse service."
  type = list(object({
    project_id       = string
    connection_limit = optional(number, 10)
  }))
  default = []
}

variable "create_topic" {
  description = "Whether to create the Kafka topic used by the ClickPipe. This does not produce records."
  type        = bool
  default     = true
}

variable "topic_name" {
  description = "Kafka topic name used by the ClickPipe."
  type        = string
  default     = "clickpipes-demo"
}

variable "topic_partitions" {
  description = "Number of partitions for the optional Kafka topic."
  type        = number
  default     = 3
}

variable "topic_replication_factor" {
  description = "Replication factor for the optional Kafka topic."
  type        = number
  default     = 3
}

variable "rpe_description_prefix" {
  description = "Description prefix for broker RPEs."
  type        = string
  default     = "GCP Managed Kafka PSC endpoint"
}

variable "create_clickpipe" {
  description = "When false, create source infrastructure and RPE connectivity only. When true, create the ClickPipe and start data loading. The module does not produce Kafka records."
  type        = bool
  default     = false
}

variable "clickpipe_name" {
  description = "Name of the ClickPipe to create when create_clickpipe is true."
  type        = string
  default     = "GCP Managed Kafka PSC"
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

variable "consumer_group" {
  description = "Kafka consumer group for the ClickPipe. Required when create_clickpipe is true."
  type        = string
  default     = null
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
