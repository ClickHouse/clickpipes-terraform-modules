output "cluster_arn" {
  description = "MSK Serverless cluster ARN."
  value       = aws_msk_serverless_cluster.kafka.arn
}

output "cluster_name" {
  description = "MSK Serverless cluster name."
  value       = aws_msk_serverless_cluster.kafka.cluster_name
}

output "cluster_uuid" {
  description = "MSK Serverless cluster UUID used in MSK IAM ARNs."
  value       = aws_msk_serverless_cluster.kafka.cluster_uuid
}

output "bootstrap_endpoint" {
  description = "MSK Serverless SASL/IAM bootstrap endpoint used by ClickPipes."
  value       = aws_msk_serverless_cluster.kafka.bootstrap_brokers_sasl_iam
}

output "bootstrap_host" {
  description = "MSK Serverless bootstrap DNS host targeted by the VPC Lattice resource configuration."
  value       = local.msk_bootstrap_host
}

output "broker_wildcard_private_dns" {
  description = "Wildcard DNS name mapped in ClickPipes private DNS. Covers bootstrap and advertised bNNN broker hostnames."
  value       = local.msk_broker_wildcard
}

output "topic_arn" {
  description = "MSK IAM topic ARN for the configured topic."
  value       = local.msk_topic_arn
}

output "vpc_id" {
  description = "VPC ID hosting MSK Serverless and the VPC Lattice resource gateway."
  value       = aws_vpc.kafka.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by MSK Serverless and the VPC Lattice resource gateway."
  value       = [for az in local.azs : aws_subnet.private[az].id]
}

output "msk_security_group_id" {
  description = "Security group ID attached to the MSK Serverless cluster."
  value       = aws_security_group.msk.id
}

output "vpc_resource_configuration_id" {
  description = "VPC Lattice resource configuration ID shared with ClickPipes."
  value       = aws_vpclattice_resource_configuration.msk_bootstrap.id
}

output "vpc_resource_configuration_arn" {
  description = "VPC Lattice resource configuration ARN shared with ClickPipes."
  value       = aws_vpclattice_resource_configuration.msk_bootstrap.arn
}

output "vpc_resource_share_arn" {
  description = "AWS RAM resource share ARN for the VPC Lattice resource configuration."
  value       = aws_ram_resource_share.msk_vpc_resource.arn
}

output "clickpipe_msk_reader_role_arn" {
  description = "Customer AWS IAM role ARN assumed by ClickPipes for MSK IAM authentication."
  value       = aws_iam_role.clickpipe_msk_reader.arn
}

output "reverse_private_endpoint_ids" {
  description = "ClickPipes Reverse Private Endpoint IDs."
  value       = [clickhouse_clickpipes_reverse_private_endpoint.msk_vpc_resource.id]
}

output "reverse_private_endpoint_statuses" {
  description = "ClickPipes Reverse Private Endpoint statuses."
  value = {
    msk = clickhouse_clickpipes_reverse_private_endpoint.msk_vpc_resource.status
  }
}

output "endpoint_ids" {
  description = "Provider-side endpoint IDs."
  value       = [clickhouse_clickpipes_reverse_private_endpoint.msk_vpc_resource.endpoint_id]
}

output "reverse_private_endpoint_dns_names" {
  description = "DNS names returned by the ClickPipes Reverse Private Endpoint."
  value = concat(
    clickhouse_clickpipes_reverse_private_endpoint.msk_vpc_resource.dns_names != null ? clickhouse_clickpipes_reverse_private_endpoint.msk_vpc_resource.dns_names : [],
    clickhouse_clickpipes_reverse_private_endpoint.msk_vpc_resource.private_dns_names != null ? clickhouse_clickpipes_reverse_private_endpoint.msk_vpc_resource.private_dns_names : [],
  )
}

output "custom_private_dns_mappings" {
  description = "Custom private DNS mappings registered for the RPE."
  value = [
    {
      reverse_private_endpoint_id = clickhouse_clickpipes_reverse_private_endpoint.msk_vpc_resource.id
      private_dns_name            = local.msk_broker_wildcard
    },
  ]
}

output "clickpipe_id" {
  description = "ClickPipe ID when create_clickpipe is true."
  value       = try(clickhouse_clickpipe.msk[0].id, null)
}

output "clickpipe_state" {
  description = "ClickPipe state when create_clickpipe is true."
  value       = try(clickhouse_clickpipe.msk[0].state, null)
}
