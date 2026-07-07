# Confluent Cloud Serverless ClickPipes Module

Creates a Confluent Cloud Enterprise/serverless Kafka cluster, an ingress private connectivity gateway and access point, a ClickPipes Reverse Private Endpoint (RPE), custom private DNS mappings, and optionally a Kafka ClickPipe.

The module supports AWS PrivateLink (`cloud = "AWS"`) and GCP Private Service Connect (`cloud = "GCP"`).

`create_clickpipe` controls data loading. Leave it `false` to create source infrastructure and RPE connectivity only. Set it to `true` after your Kafka topic exists and contains data.

## Private DNS

Confluent serverless access point hostnames resolve through a public GLB hostname that CNAMEs to an access-point DNS domain. The ClickPipes custom private DNS currently does not support resolving public hostnames into a custom mapped CNAME targets. To support this flow, the module configures both mappings on the RPE:

- `*.{region}.{cloud}.accesspoint.glb.confluent.cloud` — maps the original GLB hostname and is required for ClickPipes DNS proxy compatibility.
- `*.{access_point_dns_domain}` — matches Confluent's documented private DNS domain and will become useful once CNAME-target mapping is supported end to end.

This has an important implication for the Reverse Private Endpoint setup. It is not possible to create multiple RPEs for multiple access points in the samer ClickHouse service. This is a known limitation that is being tracked by ClickPipes team.

## Sequencing

The ClickHouse Terraform provider returns the RPE once it leaves `Provisioning`, exposing the provider-side endpoint ID even while the connection is pending acceptance. The Confluent access point uses that endpoint ID to accept the connection, and the DNS mappings are patched after the access point is created.

The module does not create Kafka topics or produce sample data. Create and seed the topic from a network location that can resolve the private DNS records before setting `create_clickpipe = true`.
