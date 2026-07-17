variable "clickhouse_service_id" {
  description = "Existing ClickHouse Cloud service ID that will own the RPEs and ClickPipe."
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
  description = "AWS region for the MSK Express cluster and endpoint services."
  type        = string
}

variable "supported_regions" {
  description = "AWS regions from which PrivateLink consumers can access the endpoint services. Set this to the ClickPipes service region for cross-region PrivateLink."
  type        = list(string)
  default     = []
}

variable "resource_prefix" {
  description = "Prefix for AWS resource names. Must fit NLB and target group name limits."
  type        = string
  default     = "cp-msk-vpce"

  validation {
    condition     = length(var.resource_prefix) <= 24
    error_message = "resource_prefix must be 24 characters or fewer."
  }
}

variable "az_count" {
  description = "Number of availability zones to use for the MSK Express cluster and NLBs."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2
    error_message = "az_count must be at least 2."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the private VPC that hosts MSK Express and endpoint-service NLBs."
  type        = string
  default     = "10.90.0.0/16"
}

variable "private_subnet_newbits" {
  description = "Additional subnet bits for private subnets. The default creates /24 subnets from the /16 VPC CIDR."
  type        = number
  default     = 8
}

variable "kafka_version" {
  description = "Kafka version for the MSK Express cluster."
  type        = string
  default     = "3.8.x"
}

variable "broker_instance_type" {
  description = "MSK Express broker instance type."
  type        = string
  default     = "express.m7g.large"

  validation {
    condition     = can(regex("^express\\.", var.broker_instance_type))
    error_message = "broker_instance_type must be an MSK Express broker type, for example express.m7g.large."
  }
}

variable "number_of_broker_nodes" {
  description = "Number of MSK Express broker nodes. Must be a multiple of az_count."
  type        = number
  default     = 3

  validation {
    condition     = var.number_of_broker_nodes >= 2
    error_message = "number_of_broker_nodes must be at least 2."
  }
}

variable "kafka_port" {
  description = "MSK IAM listener port."
  type        = number
  default     = 9098
}

variable "endpoint_service_acceptance_required" {
  description = "Whether endpoint connection requests to the broker endpoint services require manual acceptance."
  type        = bool
  default     = false
}

variable "broker_target_reconciliation_schedule_expression" {
  description = "EventBridge Scheduler expression for reconciling MSK broker IPs with NLB target groups."
  type        = string
  default     = "rate(1 minute)"

  validation {
    condition     = length(trimspace(var.broker_target_reconciliation_schedule_expression)) > 0
    error_message = "broker_target_reconciliation_schedule_expression must not be empty."
  }
}

variable "broker_target_reconciler_log_retention_days" {
  description = "CloudWatch Logs retention for the broker target reconciler Lambda."
  type        = number
  default     = 14
}

variable "broker_target_reconciler_alarm_actions" {
  description = "ARNs notified when broker target reconciliation fails."
  type        = list(string)
  default     = []
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
  description = "Base description for ClickPipes Reverse Private Endpoints. Broker number is appended."
  type        = string
  default     = "MSK Express VPC endpoint service"
}

variable "create_clickpipe" {
  description = "When false, create source infrastructure and RPE connectivity only. When true, create the ClickPipe and start data loading. The module does not produce Kafka records."
  type        = bool
  default     = false
}

variable "clickpipe_name" {
  description = "Name of the ClickPipe to create when create_clickpipe is true."
  type        = string
  default     = "AWS MSK VPC endpoint service"
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
