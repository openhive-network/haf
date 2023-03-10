DROP TYPE IF EXISTS hive.metadata_record_type CASCADE;
CREATE TYPE hive.metadata_record_type AS
(
    account_name TEXT
    , json_metadata TEXT
    , posting_json_metadata TEXT
);

DROP FUNCTION IF EXISTS hive.get_metadata;
CREATE OR REPLACE FUNCTION hive.get_metadata(IN _operation_body hive.operation)
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
CREATE OR REPLACE FUNCTION hive.is_metadata_operation(IN _operation_body hive.operation)
RETURNS Boolean
AS 'MODULE_PATHNAME', 'is_metadata_operation' LANGUAGE C;
