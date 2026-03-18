-- Create the HAF database and install the hive_fork_manager extension.
-- This runs as postgres superuser during first-boot initialization.

CREATE DATABASE haf_block_log WITH OWNER haf_admin TABLESPACE haf_tablespace ENCODING UTF8 LC_COLLATE 'C' LC_CTYPE 'C' TEMPLATE template0;

\c haf_block_log

-- Create extension as haf_admin (the database owner) for correct ownership
SET ROLE haf_admin;
CREATE EXTENSION hive_fork_manager CASCADE;
RESET ROLE;

GRANT CREATE ON DATABASE haf_block_log TO hive_applications_owner_group;
