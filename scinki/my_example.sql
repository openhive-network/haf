
-- my_example.sql
    -- from test_examples.sh

       -- create_db_roles.sql
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




-- #setup_db.sh  
sudo -Enu "$DB_ADMIN" psql -aw $POSTGRES_ACCESS -d postgres -v ON_ERROR_STOP=on -U "$DB_ADMIN" -f - << EOF
  DROP DATABASE IF EXISTS $DB_NAME;
  CREATE DATABASE $DB_NAME WITH OWNER $DB_ADMIN TABLESPACE ${HAF_TABLESPACE_NAME};
EOF

sudo -Enu "$DB_ADMIN" psql -aw $POSTGRES_ACCESS -d "$DB_NAME" -v ON_ERROR_STOP=on -U "$DB_ADMIN" -c 'CREATE EXTENSION hive_fork_manager CASCADE;' 

for u in "${DB_USERS[@]}"; do
  sudo -Enu "$DB_ADMIN" psql -aw $POSTGRES_ACCESS -d postgres -v ON_ERROR_STOP=on -U "$DB_ADMIN" -f - << EOF
    GRANT CREATE ON DATABASE $DB_NAME TO $u;
EOF
