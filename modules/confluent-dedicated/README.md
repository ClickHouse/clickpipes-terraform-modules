# Confluent Cloud Dedicated ClickPipes Module

Creates Confluent Cloud Dedicated Kafka private networking, ClickPipes Reverse Private Endpoint (RPE) resources, custom private DNS mappings, and optionally a Kafka ClickPipe.

The module supports AWS PrivateLink (`cloud = "AWS"`) and GCP Private Service Connect (`cloud = "GCP"`).

`create_clickpipe` controls data loading. Leave it `false` to create source infrastructure and RPE connectivity only. Set it to `true` after your Kafka topic exists and contains data.

## Cloud-specific inputs

- AWS requires `clickpipes_consumer_aws_account_id` and AWS availability zone IDs in `network_zones`, for example `euc1-az1`.
- GCP requires `clickpipes_consumer_gcp_project_id` and GCP zones in `network_zones`, for example `us-central1-a`.

## Private DNS

The module configures ClickPipes custom private DNS mappings for Confluent's private DNS domain:

- AWS maps `*.{dns_domain}` and `*.{zone}.{dns_domain}` to the single VPC endpoint service RPE.
- GCP maps `*.{zone}.{dns_domain}` per zone and maps `*.{dns_domain}` on the first sorted zone.

The module does not create Kafka topics or produce sample data. Create and seed the topic before setting `create_clickpipe = true`.
