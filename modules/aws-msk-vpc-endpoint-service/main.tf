data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs         = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  broker_keys = [for index in range(var.number_of_broker_nodes) : tostring(index + 1)]

  broker_nodes_by_key = {
    for node in data.aws_msk_broker_nodes.kafka.node_info_list : tostring(node.broker_id) => node
  }

  broker_hosts_by_key = {
    for key in local.broker_keys : key => split(":", sort(tolist(local.broker_nodes_by_key[key].endpoints))[0])[0]
  }

  bootstrap_hosts = [for endpoint in split(",", aws_msk_cluster.kafka.bootstrap_brokers_sasl_iam) : split(":", endpoint)[0]]

  bootstrap_hosts_by_key = {
    for key in local.broker_keys : key => [
      for index, host in local.bootstrap_hosts : host
      if local.broker_keys[index % length(local.broker_keys)] == key
    ]
  }

  custom_private_dns_names_by_key = {
    for key in local.broker_keys : key => distinct(concat(
      [local.broker_hosts_by_key[key]],
      local.bootstrap_hosts_by_key[key],
    ))
  }

  msk_cluster_arn = aws_msk_cluster.kafka.arn
  msk_topic_arn   = "arn:${data.aws_partition.current.partition}:kafka:${var.region}:${data.aws_caller_identity.current.account_id}:topic/${aws_msk_cluster.kafka.cluster_name}/${aws_msk_cluster.kafka.cluster_uuid}/${var.topic_name}"
  msk_group_arn   = var.consumer_group == null ? null : "arn:${data.aws_partition.current.partition}:kafka:${var.region}:${data.aws_caller_identity.current.account_id}:group/${aws_msk_cluster.kafka.cluster_name}/${aws_msk_cluster.kafka.cluster_uuid}/${var.consumer_group}"

  clickpipes_allowed_principal = "arn:${data.aws_partition.current.partition}:iam::${var.clickpipes_consumer_aws_account_id}:root"
  tags                         = var.tags
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
  description = "MSK Express access from endpoint-service NLBs"
  vpc_id      = aws_vpc.kafka.id

  tags = merge(local.tags, { Name = "${var.resource_prefix}-msk" })
}

resource "aws_security_group_rule" "msk_ingress_from_vpc" {
  type              = "ingress"
  security_group_id = aws_security_group.msk.id
  cidr_blocks       = [var.vpc_cidr]
  protocol          = "tcp"
  from_port         = var.kafka_port
  to_port           = var.kafka_port
  description       = "Allow NLB and in-VPC producers to reach MSK IAM port"
}

resource "aws_security_group_rule" "msk_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.msk.id
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_msk_cluster" "kafka" {
  cluster_name           = var.resource_prefix
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.number_of_broker_nodes

  broker_node_group_info {
    instance_type = var.broker_instance_type
    client_subnets = [
      for az in local.azs : aws_subnet.private[az].id
    ]
    security_groups = [aws_security_group.msk.id]
  }

  client_authentication {
    sasl {
      iam = true
    }
  }

  tags = length(local.tags) == 0 ? null : local.tags

  lifecycle {
    precondition {
      condition     = var.number_of_broker_nodes % var.az_count == 0
      error_message = "number_of_broker_nodes must be a multiple of az_count."
    }
  }
}

data "aws_msk_broker_nodes" "kafka" {
  cluster_arn = aws_msk_cluster.kafka.arn
}

resource "aws_lb" "broker" {
  for_each = toset(local.broker_keys)

  name                             = "${var.resource_prefix}-${each.key}"
  internal                         = true
  load_balancer_type               = "network"
  subnets                          = [for az in local.azs : aws_subnet.private[az].id]
  enable_cross_zone_load_balancing = true

  tags = merge(local.tags, { Name = "${var.resource_prefix}-${each.key}" })
}

resource "aws_lb_target_group" "broker" {
  for_each = toset(local.broker_keys)

  name        = "${var.resource_prefix}-${each.key}-tg"
  port        = var.kafka_port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = aws_vpc.kafka.id

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = "traffic-port"
    interval            = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(local.tags, {
    Name        = "${var.resource_prefix}-${each.key}-tg"
    MSKBrokerId = each.key
  })
}

resource "aws_lb_target_group_attachment" "broker" {
  for_each = toset(local.broker_keys)

  target_group_arn = aws_lb_target_group.broker[each.key].arn
  target_id        = local.broker_nodes_by_key[each.key].client_vpc_ip_address
  port             = var.kafka_port

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "broker" {
  for_each = toset(local.broker_keys)

  load_balancer_arn = aws_lb.broker[each.key].arn
  port              = var.kafka_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.broker[each.key].arn
  }
}

resource "aws_vpc_endpoint_service" "broker" {
  for_each = toset(local.broker_keys)

  acceptance_required        = var.endpoint_service_acceptance_required
  allowed_principals         = [local.clickpipes_allowed_principal]
  network_load_balancer_arns = [aws_lb.broker[each.key].arn]
  supported_regions          = var.supported_regions

  tags = merge(local.tags, { Name = "${var.resource_prefix}-${each.key}" })

  depends_on = [aws_lb_listener.broker]
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
  name               = "${var.resource_prefix}-msk-reader"
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

resource "clickhouse_clickpipes_reverse_private_endpoint" "broker" {
  for_each = toset(local.broker_keys)

  service_id                = var.clickhouse_service_id
  description               = "${var.rpe_description} broker ${each.key}"
  type                      = "VPC_ENDPOINT_SERVICE"
  vpc_endpoint_service_name = aws_vpc_endpoint_service.broker[each.key].service_name
}

resource "clickhouse_clickpipes_reverse_private_endpoint_custom_private_dns" "broker" {
  for_each = toset(local.broker_keys)

  service_id                  = var.clickhouse_service_id
  reverse_private_endpoint_id = clickhouse_clickpipes_reverse_private_endpoint.broker[each.key].id

  mapping = [for private_dns_name in local.custom_private_dns_names_by_key[each.key] : {
    private_dns_name = private_dns_name
  }]
}

resource "clickhouse_clickpipe" "msk" {
  count = var.create_clickpipe ? 1 : 0

  name       = var.clickpipe_name
  service_id = var.clickhouse_service_id

  depends_on = [
    clickhouse_clickpipes_reverse_private_endpoint_custom_private_dns.broker,
    aws_iam_role_policy.clickpipe_msk_reader,
    aws_lambda_invocation.broker_targets,
  ]

  scaling = {
    replicas = 1
  }

  source = {
    kafka = {
      type           = "msk"
      format         = var.kafka_format
      brokers        = aws_msk_cluster.kafka.bootstrap_brokers_sasl_iam
      topics         = var.topic_name
      consumer_group = var.consumer_group
      authentication = "IAM_ROLE"
      iam_role       = aws_iam_role.clickpipe_msk_reader.arn

      offset = {
        strategy = var.offset_strategy
      }

      reverse_private_endpoint_ids = [
        for key in local.broker_keys : clickhouse_clickpipes_reverse_private_endpoint.broker[key].id
      ]
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
