variable "project_id" {
  description = "GCP project ID where Cloud SQL is created."
  type        = string
}

variable "region" {
  description = "GCP region for Cloud SQL and the ClickHouse service."
  type        = string
}

variable "name_prefix" {
  description = "Name for the Cloud SQL instance and related resources."
  type        = string
  default     = "clickpipes-cloud-sql-native-psc"
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

variable "psc_allowed_consumer_projects" {
  description = "GCP project IDs or numbers allowed to connect to the Cloud SQL native PSC endpoint. Include the ClickPipes consumer project for your ClickHouse service."
  type        = list(string)
  default     = []
}

variable "rpe_description" {
  description = "Description for the ClickPipes Reverse Private Endpoint."
  type        = string
  default     = "Cloud SQL native PSC endpoint"
}

variable "create_clickpipe" {
  description = "When false, create source infrastructure and RPE connectivity only. When true, create the ClickPipe and start data loading. The module does not create source tables or seed data."
  type        = bool
  default     = false
}

variable "clickpipe_name" {
  description = "Name of the ClickPipe to create when create_clickpipe is true."
  type        = string
  default     = "GCP Cloud SQL native PSC"
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
