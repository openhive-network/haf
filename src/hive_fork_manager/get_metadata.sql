DROP TYPE IF EXISTS hive.metadata_record_type CASCADE;
CREATE TYPE hive.metadata_record_type AS
(
    account_name TEXT
    , json_metadata TEXT
    , posting_json_metadata TEXT
);

DROP FUNCTION IF EXISTS hive.get_metadata;
CREATE OR REPLACE FUNCTION hive.get_metadata(IN _operation_body text)
RETURNS SETOF hive.metadata_record_type
AS 'MODULE_PATHNAME', 'get_metadata' LANGUAGE C;

DROP TYPE IF EXISTS hive.get_metadata_operations_type CASCADE;
CREATE TYPE hive.get_metadata_operations_type AS
(
      get_metadata_operations TEXT
);

DROP FUNCTION IF EXISTS hive.get_metadata_operations;
CREATE OR REPLACE FUNCTION hive.get_metadata_operations()
RETURNS SETOF hive.get_metadata_operations_type
AS 'MODULE_PATHNAME', 'get_metadata_operations' LANGUAGE C;

DROP FUNCTION IF EXISTS hive.is_metadata_operation;
CREATE OR REPLACE FUNCTION hive.is_metadata_operation(IN _full_op TEXT)
RETURNS Boolean
LANGUAGE plpgsql
IMMUTABLE
AS
$$
DECLARE
    __j JSON;
    __op TEXT;
BEGIN
    BEGIN
        __j := _full_op AS JSON;
    EXCEPTION   
        WHEN others THEN
        RETURN false;
    END;
    __op := 'hive::protocol::' ||  BTRIM((json_extract_path(__j, 'type') :: TEXT), '"');
    RETURN EXISTS(SELECT * FROM  hive.get_metadata_operations() WHERE  __op =  get_metadata_operations);
END
$$;
