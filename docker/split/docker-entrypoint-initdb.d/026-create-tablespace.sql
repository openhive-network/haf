-- Create the HAF tablespace for storing database data.
-- The directory /var/lib/postgresql/tablespace is created by the entrypoint.
-- This only runs on first boot, so the tablespace won't already exist.
CREATE TABLESPACE haf_tablespace OWNER haf_admin LOCATION '/var/lib/postgresql/tablespace';
