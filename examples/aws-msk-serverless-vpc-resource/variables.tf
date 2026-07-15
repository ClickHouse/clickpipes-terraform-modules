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

variable "clickhouse_service_iam_role" {
  type = string
}

variable "clickpipes_consumer_aws_account_id" {
  type = string
}

variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "resource_prefix" {
  type    = string
  default = "clickpipes-msk-serverless"
}

variable "az_count" {
  type    = number
  default = 2
}

variable "vpc_cidr" {
  type    = string
  default = "10.80.0.0/16"
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

variable "clickpipe_name" {
  type    = string
  default = "AWS MSK Serverless VPC Resource"
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

variable "tags" {
  type    = map(string)
  default = {}
}
