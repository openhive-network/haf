DROP TYPE IF EXISTS hive.metadata_record_type CASCADE;
CREATE TYPE hive.metadata_record_type AS
(
    account_name TEXT
    , json_metadata TEXT
    , posting_json_metadata TEXT
);

DROP FUNCTION IF EXISTS hive.get_metadata;
CREATE OR REPLACE FUNCTION hive.get_metadata(IN _operation_body hafd.operation, IN _is_hf21 bool)
RETURNS SETOF hive.metadata_record_type
AS 'MODULE_PATHNAME', 'get_metadata' LANGUAGE C;

