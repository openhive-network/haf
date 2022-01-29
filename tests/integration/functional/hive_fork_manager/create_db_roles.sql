CREATE OR REPLACE FUNCTION create_roles()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$$
DECLARE
    __db_name TEXT;
BEGIN
    IF NOT EXISTS ( SELECT FROM pg_catalog.pg_roles WHERE  rolname = 'test_hived' ) THEN
        CREATE ROLE test_hived LOGIN PASSWORD 'test' INHERIT IN ROLE hived_group;
    END IF;

    IF NOT EXISTS ( SELECT FROM pg_catalog.pg_roles WHERE  rolname = 'alice' ) THEN
        CREATE ROLE alice LOGIN PASSWORD 'test' INHERIT IN ROLE hive_applications_group;
    END IF;

    IF NOT EXISTS ( SELECT FROM pg_catalog.pg_roles WHERE  rolname = 'bob' ) THEN
        CREATE ROLE bob LOGIN PASSWORD 'test' INHERIT IN ROLE hive_applications_group;
    END IF;
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
    DROP OWNED BY test_hived;
    DROP ROLE IF EXISTS test_hived;
END;
$$
;

SELECT create_roles();
