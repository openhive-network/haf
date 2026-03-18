-- Create the HAF tablespace for storing database data.
-- The directory /var/lib/postgresql/tablespace is created by the entrypoint.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tablespace WHERE spcname = 'haf_tablespace') THEN
        CREATE TABLESPACE haf_tablespace OWNER haf_admin LOCATION '/var/lib/postgresql/tablespace';
    END IF;
END
$$;
