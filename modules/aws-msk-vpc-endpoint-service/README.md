# AWS MSK VPC Endpoint Service

This module creates an AWS MSK provisioned Express cluster and exposes each broker to ClickPipes through an AWS PrivateLink VPC endpoint service backed by a broker-specific Network Load Balancer.

It is intended for cases where MSK multi-VPC connectivity is not available or not sufficient, including cross-region PrivateLink testing and MSK Express brokers.

It creates:

- A private VPC with private subnets.
- An MSK Express cluster with IAM/SASL authentication.
- One internal Network Load Balancer per MSK broker.
- One IP target group per broker targeting that broker private IP on port `9098`.
- One VPC endpoint service per broker.
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
