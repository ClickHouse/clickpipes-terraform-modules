# GCP Cloud SQL Native PSC ClickPipes Module

Creates a Cloud SQL for PostgreSQL instance with native Private Service Connect enabled, a ClickPipes Reverse Private Endpoint, and optionally a snapshot ClickPipe.

`create_clickpipe` controls data loading. Leave it `false` to create the source and RPE only. Set it to `true` after your source table and data exist.

The module creates the database and database user, but it does not create source tables or insert rows.
