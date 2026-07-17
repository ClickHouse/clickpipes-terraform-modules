# AWS MSK VPC Endpoint Service

This module creates an AWS MSK provisioned Express cluster and exposes each broker to ClickPipes through an AWS PrivateLink VPC endpoint service backed by a broker-specific Network Load Balancer.

It is intended for cases where MSK multi-VPC connectivity is not available or not sufficient, including cross-region PrivateLink and MSK Express brokers.

It creates:

- A private VPC with private subnets.
- An MSK Express cluster with IAM/SASL authentication.
- One internal Network Load Balancer per MSK broker.
- One IP target group per broker targeting that broker private IP on port `9098`.
- One VPC endpoint service per broker.
- A scheduled Lambda that keeps target groups aligned with current MSK broker IPs.
- One ClickPipes reverse private endpoint of type `VPC_ENDPOINT_SERVICE` per broker.
- Exact ClickPipes custom private DNS mappings for each original MSK bootstrap and broker hostname.
- An IAM role ClickPipes can assume to authenticate to MSK using IAM.
- Optionally, a Kafka ClickPipe.

The module does not create Kafka topics or produce records. Create the topic and data out of band before setting `create_clickpipe = true`.

## Networking Model

Kafka clients bootstrap from MSK bootstrap hostnames and then reconnect to broker-specific advertised hostnames from Kafka metadata. To preserve broker affinity, this module does not send all broker names through one NLB. Instead, it creates one PrivateLink path per broker:

```text
b-1.<cluster>.c2.kafka.<region>.amazonaws.com
boot-abc.<cluster>.c2.kafka.<region>.amazonaws.com
  -> ClickPipes RPE 1
  -> VPC endpoint service 1
  -> NLB 1
  -> broker 1 private IP

b-2.<cluster>.c2.kafka.<region>.amazonaws.com
boot-def.<cluster>.c2.kafka.<region>.amazonaws.com
  -> ClickPipes RPE 2
  -> VPC endpoint service 2
  -> NLB 2
  -> broker 2 private IP
```

Because the NLBs are TCP passthrough, clients still use the original MSK broker hostname for TLS SNI and certificate validation.

## Broker Target Reconciliation

MSK can replace a broker and assign it a new private IP. NLB IP target registrations do not follow that change automatically, so this module runs an EventBridge-scheduled Lambda that reads the current brokers from the MSK `ListNodes` API.

The reconciler uses the MSK broker ID rather than the order returned by the API. When an IP changes, it registers the current IP first and removes stale targets only after the current target passes the NLB health check. A broker ID or advertised-hostname change fails reconciliation without changing targets because the broker-specific ClickPipes DNS mapping may also need a Terraform apply.

The schedule defaults to once per minute and can be changed:

```hcl
broker_target_reconciliation_schedule_expression = "rate(5 minutes)"
```

The initial Terraform apply invokes the reconciler synchronously and waits for healthy targets before creating an optional ClickPipe. A newly registered target gets one scheduled interval to become healthy; if it is still unhealthy on the next run, the `broker_target_reconciler_alarm_arn` CloudWatch alarm enters `ALARM`. Set `broker_target_reconciler_alarm_actions` to SNS topic or other supported action ARNs to receive notifications.

At the one-minute default, the reconciler runs about 43,800 times per month. This normally fits within the Lambda, EventBridge Scheduler, CloudWatch Logs, and CloudWatch alarm free tiers. Without free-tier capacity, the scheduler, 128 MB Lambda, one alarm, and small log volume are expected to cost roughly `$0.15-$0.30` per cluster per month, depending on region and execution duration.

## Cross-Region PrivateLink

For cross-region PrivateLink, set `supported_regions` to the ClickPipes service region:

```hcl
supported_regions = ["eu-west-1"]
```

The AWS provider for this module should be configured in the MSK source region.

## Required Inputs

- `clickhouse_service_id`
- `clickhouse_service_iam_role`
- `clickpipes_consumer_aws_account_id`
- `region`

## ClickPipe Creation

`create_clickpipe` defaults to `false`. When enabling it, set:

- `topic_name`
- `consumer_group`
- `destination_table`
- `columns`

Example columns for JSONEachRow records with `id` and `payload` fields:

```hcl
columns = [
  { name = "id", type = "UInt64" },
  { name = "payload", type = "String" },
]
```
