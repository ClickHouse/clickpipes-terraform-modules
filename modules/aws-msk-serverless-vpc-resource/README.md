# AWS MSK Serverless VPC Resource

This module creates an AWS MSK Serverless cluster and exposes it to ClickPipes through a ClickPipes `VPC_RESOURCE` reverse private endpoint backed by VPC Lattice resource configuration.

It creates:

- A private VPC with private subnets.
- An MSK Serverless cluster with IAM/SASL authentication.
- A VPC Lattice resource gateway in the MSK VPC.
- A single VPC Lattice DNS resource configuration targeting the MSK Serverless bootstrap host on port `9098`.
- An AWS RAM share for the resource configuration to the ClickPipes AWS account.
- A ClickPipes reverse private endpoint of type `VPC_RESOURCE`.
- A wildcard ClickPipes custom private DNS mapping for the MSK Serverless DNS suffix.
- An IAM role ClickPipes can assume to authenticate to MSK using IAM.
- Optionally, a Kafka ClickPipe.

The module does not create Kafka topics or produce records. Create the topic and data out of band before setting `create_clickpipe = true`.

## Networking Model

AWS exposes one MSK Serverless bootstrap endpoint, for example:

```text
boot-<cluster-dns-id>.c3.kafka-serverless.<region>.amazonaws.com:9098
```

Kafka metadata advertises broker-specific hostnames under the same suffix, for example:

```text
b48-<cluster-dns-id>.c3.kafka-serverless.<region>.amazonaws.com:9098
b520-<cluster-dns-id>.c3.kafka-serverless.<region>.amazonaws.com:9098
```

This module creates one VPC Lattice DNS resource for the bootstrap host and maps the wildcard suffix in ClickPipes private DNS:

```text
*.c3.kafka-serverless.<region>.amazonaws.com
```

That wildcard covers both the bootstrap host and advertised broker hostnames.

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
