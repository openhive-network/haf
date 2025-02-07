CREATE DATABASE haf_block_log WITH OWNER haf_admin TABLESPACE haf_tablespace encoding UTF8 LC_COLLATE 'C' LC_CTYPE 'C' TEMPLATE template0;
\c haf_block_log
CREATE EXTENSION hive_fork_manager CASCADE;
GRANT CREATE ON DATABASE haf_block_log to hive_applications_owner_group;
