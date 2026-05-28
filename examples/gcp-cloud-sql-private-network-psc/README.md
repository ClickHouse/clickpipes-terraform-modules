# GCP Cloud SQL Private Network PSC Example

Creates Cloud SQL PostgreSQL on a private VPC, exposes it through producer-owned PSC, creates a ClickPipes RPE, and optionally creates a ClickPipe.

The example does not create source tables or data. Keep `create_clickpipe = false` until your table exists and contains the data you want ClickPipes to load.
