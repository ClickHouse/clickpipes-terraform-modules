output "cluster_arn" {
  description = "MSK Express cluster ARN."
  value       = aws_msk_cluster.kafka.arn
}

output "cluster_name" {
  description = "MSK Express cluster name."
  value       = aws_msk_cluster.kafka.cluster_name
}

output "cluster_uuid" {
  description = "MSK cluster UUID used in MSK IAM ARNs."
  value       = aws_msk_cluster.kafka.cluster_uuid
}

output "bootstrap_endpoint" {
  description = "MSK SASL/IAM bootstrap endpoints used by ClickPipes and seed producers."
  value       = aws_msk_cluster.kafka.bootstrap_brokers_sasl_iam
}

output "broker_hosts" {
  description = "MSK broker hostnames keyed by broker ID. These names are mapped to broker-specific RPEs."
  value       = local.broker_hosts_by_key
}

output "broker_private_ips" {
  description = "MSK broker private IPs observed during the latest Terraform refresh, keyed by broker ID."
  value = {
    for key in local.broker_keys : key => local.broker_nodes_by_key[key].client_vpc_ip_address
  }
}

output "topic_arn" {
  description = "MSK IAM topic ARN for the configured topic."
  value       = local.msk_topic_arn
}

output "vpc_id" {
  description = "VPC ID hosting MSK Express and endpoint-service NLBs."
  value       = aws_vpc.kafka.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by MSK Express, NLBs, and optional in-VPC producers."
  value       = [for az in local.azs : aws_subnet.private[az].id]
}

output "msk_security_group_id" {
  description = "Security group ID attached to the MSK Express cluster."
  value       = aws_security_group.msk.id
}

output "nlb_arns" {
  description = "Broker-specific Network Load Balancer ARNs keyed by broker ID."
  value       = { for key in local.broker_keys : key => aws_lb.broker[key].arn }
}

output "vpc_endpoint_service_names" {
  description = "Broker-specific VPC endpoint service names keyed by broker ID."
  value       = { for key in local.broker_keys : key => aws_vpc_endpoint_service.broker[key].service_name }
}

output "vpc_endpoint_service_arns" {
  description = "Broker-specific VPC endpoint service ARNs keyed by broker ID."
  value       = { for key in local.broker_keys : key => aws_vpc_endpoint_service.broker[key].arn }
}

output "clickpipe_msk_reader_role_arn" {
  description = "Customer AWS IAM role ARN assumed by ClickPipes for MSK IAM authentication."
  value       = aws_iam_role.clickpipe_msk_reader.arn
}

output "reverse_private_endpoint_ids" {
  description = "ClickPipes Reverse Private Endpoint IDs in broker order."
  value       = [for key in local.broker_keys : clickhouse_clickpipes_reverse_private_endpoint.broker[key].id]
}

output "reverse_private_endpoint_statuses" {
  description = "ClickPipes Reverse Private Endpoint statuses keyed by broker ID."
  value       = { for key in local.broker_keys : key => clickhouse_clickpipes_reverse_private_endpoint.broker[key].status }
}

output "endpoint_ids" {
  description = "Provider-side endpoint IDs in broker order."
  value       = [for key in local.broker_keys : clickhouse_clickpipes_reverse_private_endpoint.broker[key].endpoint_id]
}

output "reverse_private_endpoint_dns_names" {
  description = "DNS names returned by the ClickPipes Reverse Private Endpoints keyed by broker ID."
  value = {
    for key in local.broker_keys : key => concat(
      clickhouse_clickpipes_reverse_private_endpoint.broker[key].dns_names != null ? clickhouse_clickpipes_reverse_private_endpoint.broker[key].dns_names : [],
      clickhouse_clickpipes_reverse_private_endpoint.broker[key].private_dns_names != null ? clickhouse_clickpipes_reverse_private_endpoint.broker[key].private_dns_names : [],
    )
  }
}

output "custom_private_dns_mappings" {
  description = "Custom private DNS mappings registered for broker-specific RPEs."
  value = flatten([
    for key in local.broker_keys : [
      for private_dns_name in local.custom_private_dns_names_by_key[key] : {
        broker_id                   = key
        reverse_private_endpoint_id = clickhouse_clickpipes_reverse_private_endpoint.broker[key].id
        private_dns_name            = private_dns_name
      }
    ]
  ])
}

output "broker_target_reconciler_function_name" {
  description = "Lambda function that reconciles current MSK broker IPs with NLB target groups."
  value       = aws_lambda_function.broker_target_reconciler.function_name
}

output "broker_target_reconciliation_schedule_arn" {
  description = "EventBridge Scheduler schedule that runs broker target reconciliation."
  value       = aws_scheduler_schedule.broker_target_reconciler.arn
}

output "broker_target_reconciler_alarm_arn" {
  description = "CloudWatch alarm for broker target reconciliation failures."
  value       = aws_cloudwatch_metric_alarm.broker_target_reconciler_errors.arn
}

output "clickpipe_id" {
  description = "ClickPipe ID when create_clickpipe is true."
  value       = try(clickhouse_clickpipe.msk[0].id, null)
}

output "clickpipe_state" {
  description = "ClickPipe state when create_clickpipe is true."
  value       = try(clickhouse_clickpipe.msk[0].state, null)
}
