# GCP Confluent Cloud Dedicated PSC ClickPipes Module

Creates Confluent Cloud Dedicated Kafka on GCP Private Service Connect, ClickPipes Reverse Private Endpoints, and optionally a Kafka ClickPipe.

`create_clickpipe` controls data loading. Leave it `false` to create source infrastructure and RPE connectivity only. Set it to `true` after your Kafka topic has data.
