variable "gcp_project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east1"
}

variable "name_prefix" {
  type    = string
  default = "clickpipes-managed-kafka-example"
}

variable "clickhouse_organization_id" {
  type = string
}

variable "clickhouse_cloud_api_key" {
  type      = string
  sensitive = true
}

variable "clickhouse_cloud_api_secret" {
  type      = string
  sensitive = true
}

variable "clickhouse_service_id" {
  type = string
}

variable "psc_consumer_accept_projects" {
  type = list(object({
    project_id       = string
    connection_limit = optional(number, 10)
  }))
  default = []
}

variable "topic_name" {
  type    = string
  default = "clickpipes-demo"
}

variable "create_topic" {
  type    = bool
  default = true
}

variable "create_clickpipe" {
  description = "Set true to create the ClickPipe and start loading data after the topic has data."
  type        = bool
  default     = false
}

variable "consumer_group" {
  type    = string
  default = null
}

variable "destination_table" {
  type    = string
  default = null
}

variable "columns" {
  type = list(object({
    name = string
    type = string
  }))
  default = []
}

variable "sorting_key" {
  type    = list(string)
  default = []
}
