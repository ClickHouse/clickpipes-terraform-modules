# Confluent Cloud Serverless PSC ClickPipes Module

Creates Confluent Cloud Enterprise/serverless Kafka ingress PSC resources, a ClickPipes Reverse Private Endpoint, and optionally a Kafka ClickPipe.

`create_clickpipe` controls data loading. Leave it `false` to create source infrastructure and RPE connectivity only. Set it to `true` after your Kafka topic has data and the ingress access point DNS is ready.

## Serverless PSC sequencing

Confluent Serverless ingress PSC requires a ClickHouse-created PSC connection ID to create the Confluent access point. ClickHouse Terraform provider does not support private DNS name sequencing. It is pending release: https://github.com/ClickHouse/terraform-provider-clickhouse/pull/552