DROP DATABASE IF EXISTS psql_tools_test_db;

CREATE OR REPLACE FUNCTION create_roles()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$$
DECLARE
    __db_name TEXT;
BEGIN
    IF NOT EXISTS ( SELECT FROM pg_catalog.pg_roles WHERE  rolname = 'hived' ) THEN
        CREATE ROLE hived LOGIN PASSWORD 'test' INHERIT IN ROLE hived_group;
    END IF;

    IF NOT EXISTS ( SELECT FROM pg_catalog.pg_roles WHERE  rolname = 'alice' ) THEN
        CREATE ROLE alice LOGIN PASSWORD 'test' INHERIT IN ROLE hive_applications_group;
    END IF;

    IF NOT EXISTS ( SELECT FROM pg_catalog.pg_roles WHERE  rolname = 'bob' ) THEN
        CREATE ROLE bob LOGIN PASSWORD 'test' INHERIT IN ROLE hive_applications_group;
    END IF;

    GRANT CREATE ON DATABASE psql_tools_test_db TO alice, bob;
END;
$$
;

CREATE OR REPLACE FUNCTION drop_roles()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$$
BEGIN
    DROP OWNED BY hive_applications_group;
    DROP OWNED BY hived_group;
    DROP OWNED BY alice;
    DROP ROLE IF EXISTS alice;
    DROP OWNED BY bob;
    DROP ROLE IF EXISTS bob;
    DROP OWNED BY hived;
    DROP ROLE IF EXISTS hived;
END;
$$
;

CREATE DATABASE psql_tools_test_db
WITH
ENCODING = 'UTF8'
LC_COLLATE = 'en_US.UTF-8'
LC_CTYPE = 'en_US.UTF-8'
TEMPLATE = template0
TABLESPACE = pg_default
CONNECTION LIMIT = -1;


SELECT create_roles();
