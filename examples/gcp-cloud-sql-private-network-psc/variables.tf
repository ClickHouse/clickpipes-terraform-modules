variable "gcp_project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east1"
}

variable "name_prefix" {
  type    = string
  default = "clickpipes-cloud-sql-private-psc-example"
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

variable "create_clickpipe" {
  description = "Set true to create the ClickPipe and start loading data after source table/data exist."
  type        = bool
  default     = false
}

variable "source_table" {
  type    = string
  default = null
}

variable "target_table" {
  type    = string
  default = null
}
