# Confluent Cloud Serverless ClickPipes Module

Creates a Confluent Cloud Enterprise/serverless Kafka cluster, an ingress private connectivity gateway and access point, a ClickPipes Reverse Private Endpoint (RPE), custom private DNS mappings, and optionally a Kafka ClickPipe.

The module supports AWS PrivateLink (`cloud = "AWS"`) and GCP Private Service Connect (`cloud = "GCP"`).

`create_clickpipe` controls data loading. Leave it `false` to create source infrastructure and RPE connectivity only. Set it to `true` after your Kafka topic exists and contains data.

## Private DNS

Confluent serverless bootstrap endpoints use a public GLB hostname that CNAMEs to an access-point DNS domain. ClickPipes follows this CNAME and applies the custom private DNS mapping to the target, so public GLB bootstrap endpoints are supported without a direct GLB wildcard mapping.

The module configures only Confluent's documented private DNS mapping:

- `*.{access_point_dns_domain}` — maps the GLB hostname's CNAME target to the RPE.

This has an important implication for the Reverse Private Endpoint setup. It is not possible to create multiple RPEs for multiple access points in the samer ClickHouse service. This is a known limitation that is being tracked by ClickPipes team.

## Sequencing

The ClickHouse Terraform provider returns the RPE once it leaves `Provisioning`, exposing the provider-side endpoint ID even while the connection is pending acceptance. The Confluent access point uses that endpoint ID to accept the connection, and the DNS mappings are patched after the access point is created.

The module does not create Kafka topics or produce sample data. Create and seed the topic from a network location that can resolve the private DNS records before setting `create_clickpipe = true`.
