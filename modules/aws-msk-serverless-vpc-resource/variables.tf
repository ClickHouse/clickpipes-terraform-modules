variable "clickhouse_service_id" {
  description = "Existing ClickHouse Cloud service ID that will own the RPE and ClickPipe."
  type        = string
}

variable "clickhouse_service_iam_role" {
  description = "ClickHouse Cloud service IAM role ARN allowed to assume the MSK reader role. This is exposed as the ClickHouse service iam_role attribute."
  type        = string
}

variable "clickpipes_consumer_aws_account_id" {
  description = "AWS account ID used by the ClickPipes consumer VPC for this ClickHouse service."
  type        = string
}

variable "region" {
  description = "AWS region for MSK Serverless and the ClickHouse service."
  type        = string
}

variable "resource_prefix" {
  description = "Prefix for AWS resource names. Keep short enough for IAM role name limits."
  type        = string
  default     = "clickpipes-msk-serverless"

  validation {
    condition     = length(var.resource_prefix) <= 40
    error_message = "resource_prefix must be 40 characters or fewer."
  }
}

variable "az_count" {
  description = "Number of availability zones to use for MSK Serverless and the VPC Lattice resource gateway."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "MSK Serverless requires at least two subnets in different availability zones."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the private VPC that hosts MSK Serverless and the VPC Lattice resource gateway."
  type        = string
  default     = "10.80.0.0/16"
}

variable "private_subnet_newbits" {
  description = "Additional subnet bits for private subnets. The default creates /24 subnets from the /16 VPC CIDR."
  type        = number
  default     = 8
}

variable "resource_gateway_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to connect to the VPC Lattice resource gateway on the MSK IAM port."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "kafka_port" {
  description = "MSK Serverless IAM listener port."
  type        = number
  default     = 9098
}

variable "topic_name" {
  description = "Kafka topic name used by the ClickPipe. The module does not create or seed the topic."
  type        = string
  default     = "clickpipes-demo"
}

variable "consumer_group" {
  description = "Kafka consumer group for the ClickPipe. Required when create_clickpipe is true."
  type        = string
  default     = null
}

variable "rpe_description" {
  description = "Description for the ClickPipes Reverse Private Endpoint."
  type        = string
  default     = "MSK Serverless AWS VPC resource endpoint"
}

variable "create_clickpipe" {
  description = "When false, create source infrastructure and RPE connectivity only. When true, create the ClickPipe and start data loading. The module does not produce Kafka records."
  type        = bool
  default     = false
}

variable "clickpipe_name" {
  description = "Name of the ClickPipe to create when create_clickpipe is true."
  type        = string
  default     = "AWS MSK Serverless VPC Resource"
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

variable "tags" {
  description = "Tags applied to AWS resources that support tagging."
  type        = map(string)
  default     = {}
}
