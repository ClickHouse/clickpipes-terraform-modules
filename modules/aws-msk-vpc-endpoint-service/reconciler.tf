locals {
  broker_target_reconciler_name = "${var.resource_prefix}-target-reconciler"
  broker_target_groups = {
    for key in local.broker_keys : key => aws_lb_target_group.broker[key].arn
  }
}

data "archive_file" "broker_target_reconciler" {
  type        = "zip"
  source_file = "${path.module}/lambda/reconcile_msk_broker_targets.py"
  output_path = "${path.root}/.terraform/${local.broker_target_reconciler_name}.zip"
}

data "aws_iam_policy_document" "broker_target_reconciler_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "broker_target_reconciler" {
  name               = local.broker_target_reconciler_name
  assume_role_policy = data.aws_iam_policy_document.broker_target_reconciler_assume_role.json

  tags = length(local.tags) == 0 ? null : local.tags
}

resource "aws_cloudwatch_log_group" "broker_target_reconciler" {
  name              = "/aws/lambda/${local.broker_target_reconciler_name}"
  retention_in_days = var.broker_target_reconciler_log_retention_days

  tags = length(local.tags) == 0 ? null : local.tags
}

data "aws_iam_policy_document" "broker_target_reconciler" {
  statement {
    actions   = ["kafka:ListNodes"]
    resources = [aws_msk_cluster.kafka.arn]
  }

  statement {
    actions = [
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:RegisterTargets",
    ]
    resources = values(local.broker_target_groups)
  }

  statement {
    actions   = ["elasticloadbalancing:DescribeTargetHealth"]
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.broker_target_reconciler.arn}:*"]
  }
}

resource "aws_iam_role_policy" "broker_target_reconciler" {
  name   = local.broker_target_reconciler_name
  role   = aws_iam_role.broker_target_reconciler.id
  policy = data.aws_iam_policy_document.broker_target_reconciler.json
}

resource "aws_lambda_function" "broker_target_reconciler" {
  function_name = local.broker_target_reconciler_name
  description   = "Keep broker-specific NLB targets aligned with current MSK broker IPs"
  role          = aws_iam_role.broker_target_reconciler.arn
  handler       = "reconcile_msk_broker_targets.handler"
  runtime       = "python3.12"
  architectures = ["arm64"]
  memory_size   = 128
  timeout       = 300

  filename         = data.archive_file.broker_target_reconciler.output_path
  source_code_hash = data.archive_file.broker_target_reconciler.output_base64sha256

  reserved_concurrent_executions = 1

  environment {
    variables = {
      BROKER_HOSTS         = jsonencode(local.broker_hosts_by_key)
      BROKER_TARGET_GROUPS = jsonencode(local.broker_target_groups)
      KAFKA_PORT           = tostring(var.kafka_port)
      MSK_CLUSTER_ARN      = aws_msk_cluster.kafka.arn
    }
  }

  logging_config {
    log_format       = "JSON"
    log_group        = aws_cloudwatch_log_group.broker_target_reconciler.name
    system_log_level = "WARN"
  }

  tags = length(local.tags) == 0 ? null : local.tags

  depends_on = [aws_iam_role_policy.broker_target_reconciler]
}

resource "aws_lambda_invocation" "broker_targets" {
  function_name = aws_lambda_function.broker_target_reconciler.function_name
  input = jsonencode({
    source                   = "terraform"
    wait_for_healthy_seconds = 240
  })

  triggers = {
    broker_hosts  = sha256(jsonencode(local.broker_hosts_by_key))
    broker_ips    = sha256(jsonencode(local.broker_nodes_by_key))
    function_code = data.archive_file.broker_target_reconciler.output_base64sha256
    target_groups = sha256(jsonencode(local.broker_target_groups))
  }

  depends_on = [
    aws_lb_listener.broker,
    aws_lb_target_group_attachment.broker,
    aws_security_group_rule.msk_ingress_from_vpc,
  ]
}

resource "aws_scheduler_schedule_group" "broker_target_reconciler" {
  name = local.broker_target_reconciler_name

  tags = length(local.tags) == 0 ? null : local.tags
}

data "aws_iam_policy_document" "broker_target_scheduler_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_scheduler_schedule_group.broker_target_reconciler.arn]
    }
  }
}

resource "aws_iam_role" "broker_target_scheduler" {
  name               = "${local.broker_target_reconciler_name}-scheduler"
  assume_role_policy = data.aws_iam_policy_document.broker_target_scheduler_assume_role.json

  tags = length(local.tags) == 0 ? null : local.tags
}

data "aws_iam_policy_document" "broker_target_scheduler" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.broker_target_reconciler.arn]
  }
}

resource "aws_iam_role_policy" "broker_target_scheduler" {
  name   = "${local.broker_target_reconciler_name}-scheduler"
  role   = aws_iam_role.broker_target_scheduler.id
  policy = data.aws_iam_policy_document.broker_target_scheduler.json
}

resource "aws_scheduler_schedule" "broker_target_reconciler" {
  name                = local.broker_target_reconciler_name
  group_name          = aws_scheduler_schedule_group.broker_target_reconciler.name
  description         = "Reconcile MSK broker IPs with broker-specific NLB target groups"
  schedule_expression = var.broker_target_reconciliation_schedule_expression

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.broker_target_reconciler.arn
    role_arn = aws_iam_role.broker_target_scheduler.arn
    input    = jsonencode({ source = "eventbridge-scheduler" })

    retry_policy {
      maximum_event_age_in_seconds = 60
      maximum_retry_attempts       = 0
    }
  }

  depends_on = [
    aws_iam_role_policy.broker_target_scheduler,
    aws_lambda_invocation.broker_targets,
  ]
}

resource "aws_cloudwatch_metric_alarm" "broker_target_reconciler_errors" {
  alarm_name          = "${local.broker_target_reconciler_name}-errors"
  alarm_description   = "MSK broker target reconciliation failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.broker_target_reconciler_alarm_actions

  metric_query {
    id          = "failures"
    expression  = "lambda_errors + lambda_throttles + scheduler_target_errors + scheduler_dropped"
    label       = "Reconciliation invocation failures"
    return_data = true
  }

  metric_query {
    id          = "lambda_errors"
    return_data = false

    metric {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      period      = 60
      stat        = "Sum"

      dimensions = {
        FunctionName = aws_lambda_function.broker_target_reconciler.function_name
      }
    }
  }

  metric_query {
    id          = "lambda_throttles"
    return_data = false

    metric {
      metric_name = "Throttles"
      namespace   = "AWS/Lambda"
      period      = 60
      stat        = "Sum"

      dimensions = {
        FunctionName = aws_lambda_function.broker_target_reconciler.function_name
      }
    }
  }

  metric_query {
    id          = "scheduler_target_errors"
    return_data = false

    metric {
      metric_name = "TargetErrorCount"
      namespace   = "AWS/Scheduler"
      period      = 60
      stat        = "Sum"

      dimensions = {
        ScheduleGroup = aws_scheduler_schedule_group.broker_target_reconciler.name
      }
    }
  }

  metric_query {
    id          = "scheduler_dropped"
    return_data = false

    metric {
      metric_name = "InvocationDroppedCount"
      namespace   = "AWS/Scheduler"
      period      = 60
      stat        = "Sum"

      dimensions = {
        ScheduleGroup = aws_scheduler_schedule_group.broker_target_reconciler.name
      }
    }
  }

  tags = length(local.tags) == 0 ? null : local.tags
}
