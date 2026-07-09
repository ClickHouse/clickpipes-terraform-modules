# ClickPipes Terraform Modules

Reusable Terraform modules for ClickHouse ClickPipes private connectivity examples.

Each public module creates the source infrastructure, ClickPipes Reverse Private Endpoint (RPE) resources, and optionally a ClickPipe. Modules do not create ClickHouse services and do not create or seed demo data.

> [!IMPORTANT]  
> This repository is not actively maintained. Treat these modules as inspirational for your Terraform stack. If you still want to use them directly, use the tagged version. 

## Modules

- `modules/gcp-managed-kafka` creates Google Cloud Managed Service for Apache Kafka, producer-side PSC service attachments, ClickPipes RPEs, and optionally a Kafka ClickPipe.
- `modules/gcp-cloud-sql-native-psc` creates Cloud SQL for PostgreSQL with native Private Service Connect enabled, a ClickPipes RPE, and optionally a Postgres ClickPipe.
- `modules/gcp-cloud-sql-private-network-psc` creates Cloud SQL for PostgreSQL on a private network, exposes it through an internal TCP load balancer and producer-owned PSC service attachment, creates a ClickPipes RPE, and optionally a Postgres ClickPipe.
- `modules/aws-msk-serverless-vpc-resource` creates AWS MSK Serverless, exposes it through VPC Lattice resource configuration and ClickPipes `VPC_RESOURCE`, creates wildcard private DNS mapping and IAM authentication, and optionally a Kafka ClickPipe.
- `modules/aws-msk-vpc-endpoint-service` creates AWS MSK Express, exposes each broker through a broker-specific Network Load Balancer and VPC endpoint service, creates broker-specific ClickPipes RPEs with private DNS mappings, and optionally a Kafka ClickPipe.
- `modules/confluent-dedicated` creates Confluent Cloud Dedicated Kafka on AWS PrivateLink or GCP PSC, ClickPipes RPEs, custom private DNS mappings, and optionally a Kafka ClickPipe.
- `modules/confluent-serverless` creates Confluent Cloud Enterprise/serverless Kafka on AWS PrivateLink or GCP PSC ingress gateways, a ClickPipes RPE, custom private DNS mappings, and optionally a Kafka ClickPipe.

## `create_clickpipe`

All modules default to `create_clickpipe = false`.

When `false`, the module creates source infrastructure and Reverse Private Endpoint connectivity only. When `true`, the module provisions the ClickPipe, which starts data loading from the user's source into ClickHouse.

The modules do not create source tables, seed Kafka records, or insert sample rows. Create the source topic/table and data using your application or an out-of-band process before enabling ClickPipe data loading.

## ClickHouse Provider

Configure ClickHouse provider `>= 3.17.0` in the root module. These modules expect an existing ClickHouse Cloud service ID.

```hcl
provider "clickhouse" {
  organization_id = var.clickhouse_organization_id
  token_key       = var.clickhouse_cloud_api_key
  token_secret    = var.clickhouse_cloud_api_secret
}
```
