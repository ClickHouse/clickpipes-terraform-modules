# AWS MSK Serverless VPC Resource Example

This example creates an AWS MSK Serverless cluster and exposes it to ClickPipes with a `VPC_RESOURCE` reverse private endpoint.

It assumes you already have a ClickHouse Cloud service. Pass both the service ID and the service IAM role ARN so the module can create a customer-side MSK reader role for ClickPipes IAM authentication.

## Usage

```sh
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

By default `create_clickpipe = false`. This creates MSK Serverless, the VPC Lattice resource configuration, the AWS RAM share, the ClickPipes RPE, wildcard DNS mapping, and the IAM reader role.

Create the Kafka topic and produce records out of band, then set `create_clickpipe = true` with `consumer_group`, `destination_table`, and `columns` to create the ClickPipe.

## DNS Model

MSK Serverless returns a single bootstrap endpoint and advertises broker-specific hostnames under the same suffix. The module registers a wildcard private DNS mapping, for example:

```text
*.c3.kafka-serverless.eu-west-1.amazonaws.com
```

This covers both the bootstrap hostname and broker hostnames such as `b48-...` or `b520-...`.
