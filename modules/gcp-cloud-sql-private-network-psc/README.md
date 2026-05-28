# GCP Cloud SQL Private Network PSC ClickPipes Module

Creates Cloud SQL for PostgreSQL on a private VPC, exposes it through a producer-owned Private Service Connect service attachment, creates a ClickPipes Reverse Private Endpoint, and optionally creates a snapshot ClickPipe.

`create_clickpipe` controls data loading. Leave it `false` to create source infrastructure and RPE connectivity only. Set it to `true` after your source table and data exist.

The module creates the database and database user, but it does not create source tables or insert rows.
