# AWS MSK VPC Endpoint Service Example

This example creates an AWS MSK Express cluster and exposes each broker to ClickPipes through broker-specific VPC endpoint services backed by Network Load Balancers.

It assumes you already have a ClickHouse Cloud service. Pass both the service ID and the service IAM role ARN so the module can create a customer-side MSK reader role for ClickPipes IAM authentication.

## Usage

```sh
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

By default `create_clickpipe = false`. This creates MSK Express, NLBs, VPC endpoint services, ClickPipes RPEs, bootstrap and broker DNS mappings, and the IAM reader role.

Create the Kafka topic and produce records out of band, then set `create_clickpipe = true` with `consumer_group`, `destination_table`, and `columns` to create the ClickPipe.

## Cross-Region PrivateLink

Set `supported_regions` to the ClickPipes service region when the MSK cluster is in a different region:

```hcl
region            = "eu-central-1"
supported_regions = ["eu-west-1"]
```
