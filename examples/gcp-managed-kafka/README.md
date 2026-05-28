# GCP Managed Kafka Example

Creates Google Cloud Managed Kafka, producer-owned PSC service attachments, ClickPipes RPEs, and optionally a Kafka ClickPipe.

The example may create the Kafka topic, but it does not produce records. Keep `create_clickpipe = false` until your topic contains data to load.
