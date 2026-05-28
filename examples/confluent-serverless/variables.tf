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

variable "confluent_cloud_api_key" {
  type      = string
  sensitive = true
}

variable "confluent_cloud_api_secret" {
  type      = string
  sensitive = true
}

variable "region" {
  type    = string
  default = "us-east1"
}

variable "topic_name" {
  type    = string
  default = "clickpipes-demo"
}

variable "access_point_dns_domain" {
  description = "Set after the Confluent access point DNS domain is known. Required when create_clickpipe is true."
  type        = string
  default     = null
}

variable "create_clickpipe" {
  description = "Set true to create the ClickPipe and start loading data after the topic has data and DNS is configured."
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
