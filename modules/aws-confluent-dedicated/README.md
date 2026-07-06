# AWS Confluent Cloud Dedicated ClickPipes Module

Creates Confluent Cloud Dedicated Kafka on AWS PrivateLink, a ClickPipes Reverse Private Endpoint, custom private DNS mappings, and optionally a Kafka ClickPipe.

`create_clickpipe` controls data loading. Leave it `false` to create source infrastructure and RPE connectivity only. Set it to `true` after your Kafka topic has data.

The module does not create Kafka topics or produce records.
