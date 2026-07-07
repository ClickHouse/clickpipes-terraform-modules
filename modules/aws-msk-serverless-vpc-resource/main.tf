data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  msk_bootstrap_brokers = split(",", aws_msk_serverless_cluster.kafka.bootstrap_brokers_sasl_iam)
  msk_bootstrap_broker  = trimspace(local.msk_bootstrap_brokers[0])
  msk_bootstrap_host    = split(":", local.msk_bootstrap_broker)[0]
  msk_dns_suffix        = join(".", slice(split(".", local.msk_bootstrap_host), 1, length(split(".", local.msk_bootstrap_host))))
  msk_broker_wildcard   = "*.${local.msk_dns_suffix}"

  msk_cluster_arn = aws_msk_serverless_cluster.kafka.arn
  msk_topic_arn   = "arn:${data.aws_partition.current.partition}:kafka:${var.region}:${data.aws_caller_identity.current.account_id}:topic/${aws_msk_serverless_cluster.kafka.cluster_name}/${aws_msk_serverless_cluster.kafka.cluster_uuid}/${var.topic_name}"
  msk_group_arn   = var.consumer_group == null ? null : "arn:${data.aws_partition.current.partition}:kafka:${var.region}:${data.aws_caller_identity.current.account_id}:group/${aws_msk_serverless_cluster.kafka.cluster_name}/${aws_msk_serverless_cluster.kafka.cluster_uuid}/${var.consumer_group}"

  tags = var.tags
}

resource "aws_vpc" "kafka" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.tags, { Name = var.resource_prefix })
}

resource "aws_subnet" "private" {
  for_each = { for index, az in local.azs : az => index }

  vpc_id            = aws_vpc.kafka.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.vpc_cidr, var.private_subnet_newbits, each.value)

  tags = merge(local.tags, { Name = "${var.resource_prefix}-${each.key}" })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.kafka.id

  tags = merge(local.tags, { Name = "${var.resource_prefix}-private" })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "msk" {
  name        = "${var.resource_prefix}-msk"
  description = "MSK Serverless access from VPC Lattice resource gateway"
  vpc_id      = aws_vpc.kafka.id

  tags = length(local.tags) == 0 ? null : merge(local.tags, { Name = "${var.resource_prefix}-msk" })
}

resource "aws_security_group_rule" "msk_ingress_from_resource_gateway" {
  type                     = "ingress"
  security_group_id        = aws_security_group.msk.id
  source_security_group_id = aws_security_group.resource_gateway.id
  protocol                 = "tcp"
  from_port                = var.kafka_port
  to_port                  = var.kafka_port
  description              = "Allow VPC Lattice resource gateway to reach MSK Serverless IAM port"
}

resource "aws_security_group_rule" "msk_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.msk.id
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "resource_gateway" {
  name        = "${var.resource_prefix}-rgw"
  description = "VPC Lattice resource gateway for ClickPipes reverse private endpoint"
  vpc_id      = aws_vpc.kafka.id

  tags = length(local.tags) == 0 ? null : merge(local.tags, { Name = "${var.resource_prefix}-rgw" })
}

resource "aws_security_group_rule" "resource_gateway_ingress" {
  type              = "ingress"
  security_group_id = aws_security_group.resource_gateway.id
  protocol          = "tcp"
  from_port         = var.kafka_port
  to_port           = var.kafka_port
  cidr_blocks       = var.resource_gateway_ingress_cidr_blocks
  description       = "Allow PrivateLink/VPC Lattice traffic to the shared Kafka port"
}

resource "aws_security_group_rule" "resource_gateway_egress_to_msk" {
  type              = "egress"
  security_group_id = aws_security_group.resource_gateway.id
  cidr_blocks       = [var.vpc_cidr]
  protocol          = "tcp"
  from_port         = var.kafka_port
  to_port           = var.kafka_port
  description       = "Forward Kafka IAM traffic to MSK Serverless"
}

resource "aws_msk_serverless_cluster" "kafka" {
  cluster_name = var.resource_prefix

  vpc_config {
    subnet_ids         = [for subnet in aws_subnet.private : subnet.id]
    security_group_ids = [aws_security_group.msk.id]
  }

  client_authentication {
    sasl {
      iam {
        enabled = true
      }
    }
  }

  tags = length(local.tags) == 0 ? null : local.tags
}

resource "aws_vpclattice_resource_gateway" "msk" {
  name                           = "${var.resource_prefix}-msk"
  vpc_id                         = aws_vpc.kafka.id
  subnet_ids                     = [for subnet in aws_subnet.private : subnet.id]
  security_group_ids             = [aws_security_group.resource_gateway.id]
  resource_config_dns_resolution = "IN_VPC"

  tags = length(local.tags) == 0 ? null : local.tags

  depends_on = [aws_msk_serverless_cluster.kafka]
}

resource "aws_vpclattice_resource_configuration" "msk_bootstrap" {
  name                        = "${var.resource_prefix}-msk"
  type                        = "SINGLE"
  resource_gateway_identifier = aws_vpclattice_resource_gateway.msk.id
  protocol                    = "TCP"
  port_ranges                 = [tostring(var.kafka_port)]

  resource_configuration_definition {
    dns_resource {
      domain_name     = local.msk_bootstrap_host
      ip_address_type = "IPV4"
    }
  }

  tags = length(local.tags) == 0 ? null : local.tags
}

resource "aws_ram_resource_share" "msk_vpc_resource" {
  name                      = "${var.resource_prefix}-msk-vpc-resource"
  allow_external_principals = true

  tags = length(local.tags) == 0 ? null : local.tags
}

resource "aws_ram_resource_association" "msk_vpc_resource" {
  resource_arn       = aws_vpclattice_resource_configuration.msk_bootstrap.arn
  resource_share_arn = aws_ram_resource_share.msk_vpc_resource.arn
}

resource "aws_ram_principal_association" "clickpipes" {
  principal          = var.clickpipes_consumer_aws_account_id
  resource_share_arn = aws_ram_resource_share.msk_vpc_resource.arn
}

data "aws_iam_policy_document" "clickpipe_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.clickhouse_service_iam_role]
    }
  }
}

resource "aws_iam_role" "clickpipe_msk_reader" {
  name               = "${var.resource_prefix}-clickpipe-msk-reader"
  assume_role_policy = data.aws_iam_policy_document.clickpipe_assume_role.json

  tags = length(local.tags) == 0 ? null : local.tags
}

data "aws_iam_policy_document" "clickpipe_msk_reader" {
  statement {
    sid    = "ConnectToCluster"
    effect = "Allow"
    actions = [
      "kafka-cluster:Connect",
      "kafka-cluster:DescribeCluster",
    ]
    resources = [local.msk_cluster_arn]
  }

  statement {
    sid    = "ReadTopic"
    effect = "Allow"
    actions = [
      "kafka-cluster:DescribeTopic",
      "kafka-cluster:ReadData",
    ]
    resources = [local.msk_topic_arn]
  }

  dynamic "statement" {
    for_each = var.consumer_group == null ? [] : [local.msk_group_arn]

    content {
      sid    = "UseConsumerGroup"
      effect = "Allow"
      actions = [
        "kafka-cluster:DescribeGroup",
        "kafka-cluster:AlterGroup",
      ]
      resources = [statement.value]
    }
  }
}

resource "aws_iam_role_policy" "clickpipe_msk_reader" {
  name   = "${var.resource_prefix}-msk-reader"
  role   = aws_iam_role.clickpipe_msk_reader.id
  policy = data.aws_iam_policy_document.clickpipe_msk_reader.json
}

resource "clickhouse_clickpipes_reverse_private_endpoint" "msk_vpc_resource" {
  service_id                    = var.clickhouse_service_id
  description                   = var.rpe_description
  type                          = "VPC_RESOURCE"
  vpc_resource_configuration_id = aws_vpclattice_resource_configuration.msk_bootstrap.id
  vpc_resource_share_arn        = aws_ram_resource_share.msk_vpc_resource.arn

  depends_on = [
    aws_ram_principal_association.clickpipes,
    aws_ram_resource_association.msk_vpc_resource,
  ]
}

resource "clickhouse_clickpipes_reverse_private_endpoint_custom_private_dns" "msk" {
  service_id                  = var.clickhouse_service_id
  reverse_private_endpoint_id = clickhouse_clickpipes_reverse_private_endpoint.msk_vpc_resource.id

  mapping = [
    {
      private_dns_name = local.msk_broker_wildcard
    },
  ]
}

resource "clickhouse_clickpipe" "msk" {
  count = var.create_clickpipe ? 1 : 0

  name       = var.clickpipe_name
  service_id = var.clickhouse_service_id

  depends_on = [
    clickhouse_clickpipes_reverse_private_endpoint_custom_private_dns.msk,
    aws_iam_role_policy.clickpipe_msk_reader,
  ]

  scaling = {
    replicas = 1
  }

  source = {
    kafka = {
      type           = "msk"
      format         = var.kafka_format
      brokers        = aws_msk_serverless_cluster.kafka.bootstrap_brokers_sasl_iam
      topics         = var.topic_name
      consumer_group = var.consumer_group
      authentication = "IAM_ROLE"
      iam_role       = aws_iam_role.clickpipe_msk_reader.arn

      offset = {
        strategy = var.offset_strategy
      }

      reverse_private_endpoint_ids = [clickhouse_clickpipes_reverse_private_endpoint.msk_vpc_resource.id]
    }
  }

  destination = {
    database      = var.destination_database
    table         = var.destination_table
    managed_table = true

    table_definition = {
      engine = {
        type = "MergeTree"
      }
      sorting_key = var.sorting_key
    }

    columns = var.columns
  }

  field_mappings = [
    for column in var.columns : {
      source_field      = column.name
      destination_field = column.name
    }
  ]

  lifecycle {
    precondition {
      condition     = !var.create_clickpipe || (var.destination_table != null && var.consumer_group != null && length(var.columns) > 0)
      error_message = "destination_table, consumer_group, and columns must be set when create_clickpipe is true."
    }
  }
}
