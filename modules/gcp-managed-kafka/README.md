# GCP Managed Kafka ClickPipes Module

Creates Google Cloud Managed Service for Apache Kafka, producer-owned PSC service attachments for each broker, ClickPipes Reverse Private Endpoints, and optionally a Kafka ClickPipe.

`create_clickpipe` controls data loading. Leave it `false` to create source infrastructure and RPE connectivity only. Set it to `true` after your Kafka topic has data.

The module can optionally create the Kafka topic, but it does not produce records.
