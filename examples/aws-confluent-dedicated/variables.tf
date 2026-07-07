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

variable "clickpipes_consumer_aws_account_id" {
  type = string
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "network_zones" {
  type = list(string)
}

variable "topic_name" {
  type    = string
  default = "clickpipes-demo"
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
