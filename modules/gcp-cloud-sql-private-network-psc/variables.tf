variable "project_id" {
  description = "GCP project ID where Cloud SQL and PSC producer resources are created."
  type        = string
}

variable "region" {
  description = "GCP region for Cloud SQL, PSC, and the ClickHouse service."
  type        = string
}

variable "name_prefix" {
  description = "Name for the Cloud SQL instance and prefix for related resources."
  type        = string
  default     = "clickpipes-cloud-sql-private-psc"
}

variable "clickhouse_service_id" {
  description = "Existing ClickHouse Cloud service ID that will own the RPE and ClickPipe."
  type        = string
}

variable "database_version" {
  description = "Cloud SQL PostgreSQL database version."
  type        = string
  default     = "POSTGRES_15"
}

variable "tier" {
  description = "Cloud SQL machine tier."
  type        = string
  default     = "db-f1-micro"
}

variable "deletion_protection" {
  description = "Whether Cloud SQL deletion protection is enabled."
  type        = bool
  default     = true
}

variable "database_name" {
  description = "Database name to create."
  type        = string
  default     = "clickpipes"
}

variable "database_user" {
  description = "Database user to create."
  type        = string
  default     = "clickpipes"
}

variable "database_password" {
  description = "Optional database password. If null, a password is generated."
  type        = string
  sensitive   = true
  default     = null
}

variable "private_dns_domain" {
  description = "Private DNS suffix mapped through ClickPipes RPE custom DNS."
  type        = string
  default     = "cloudsql.internal"
}

variable "subnet_cidr" {
  description = "CIDR range for the producer VPC subnet."
  type        = string
  default     = "10.20.0.0/24"
}

variable "psc_nat_subnet_cidr" {
  description = "CIDR range for the PSC service attachment NAT subnet."
  type        = string
  default     = "10.20.1.0/28"
}

variable "proxy_only_subnet_cidr" {
  description = "CIDR range for the regional proxy-only subnet required by INTERNAL_MANAGED TCP load balancing."
  type        = string
  default     = "10.20.2.0/24"
}

variable "private_service_access_cidr" {
  description = "Base CIDR address reserved for Private Service Access to Cloud SQL."
  type        = string
  default     = "10.21.0.0"
}

variable "private_service_access_prefix_length" {
  description = "Prefix length for the Private Service Access reserved range."
  type        = number
  default     = 16
}

variable "psc_consumer_accept_projects" {
  description = "GCP project IDs or numbers auto-accepted on the producer-owned PSC service attachment. Include the ClickPipes consumer project for your ClickHouse service."
  type = list(object({
    project_id       = string
    connection_limit = optional(number, 10)
  }))
  default = []
}

variable "rpe_description" {
  description = "Description for the ClickPipes Reverse Private Endpoint."
  type        = string
  default     = "Cloud SQL private network PSC endpoint"
}

variable "create_clickpipe" {
  description = "When false, create source infrastructure and RPE connectivity only. When true, create the ClickPipe and start data loading. The module does not create source tables or seed data."
  type        = bool
  default     = false
}

variable "clickpipe_name" {
  description = "Name of the ClickPipe to create when create_clickpipe is true."
  type        = string
  default     = "GCP Cloud SQL private network PSC"
}

variable "destination_database" {
  description = "Destination ClickHouse database for the ClickPipe."
  type        = string
  default     = "default"
}

variable "source_schema" {
  description = "Source PostgreSQL schema for the ClickPipe table mapping."
  type        = string
  default     = "public"
}

variable "source_table" {
  description = "Source PostgreSQL table for the ClickPipe table mapping. Required when create_clickpipe is true."
  type        = string
  default     = null
}

variable "target_table" {
  description = "Destination ClickHouse table for the ClickPipe table mapping. Required when create_clickpipe is true."
  type        = string
  default     = null
}

variable "table_engine" {
  description = "Destination ClickHouse table engine for the ClickPipe table mapping."
  type        = string
  default     = "MergeTree"
}

variable "replication_mode" {
  description = "Postgres ClickPipe replication mode."
  type        = string
  default     = "snapshot"
}
