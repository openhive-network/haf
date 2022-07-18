CREATE TYPE hive.void_t AS ();
SELECT _variant.create_cast_in( 'hive.void_t' );
SELECT _variant.create_cast_out( 'hive.void_t' );
CREATE TYPE hive.version AS (
  v_num int8 -- uint32_t: 4 byte, but unsigned (int8)
);
SELECT _variant.create_cast_in( 'hive.version' );
SELECT _variant.create_cast_out( 'hive.version' );
CREATE TYPE hive.hardfork_version_vote AS (
  hf_version hive.version,
  hf_time timestamp
);
SELECT _variant.create_cast_in( 'hive.hardfork_version_vote' );
SELECT _variant.create_cast_out( 'hive.hardfork_version_vote' );

CREATE TYPE hive.example_optional_action AS (
  account hive.account_name_type
);
SELECT _variant.create_cast_in( 'hive.example_optional_action' );
SELECT _variant.create_cast_out( 'hive.example_optional_action' );
-- TODO: Move to hive schema
CREATE DOMAIN hive_optional_automated_action AS variant.variant;
SELECT variant.register('hive_optional_automated_action', '{ hive.example_optional_action }');

CREATE TYPE hive.example_required_action AS (
  account hive.account_name_type
);
SELECT _variant.create_cast_in( 'hive.example_required_action' );
SELECT _variant.create_cast_out( 'hive.example_required_action' );
-- TODO: Move to hive schema
CREATE DOMAIN hive_required_automated_action AS variant.variant;
SELECT variant.register('hive_required_automated_action', '{ hive.example_required_action }');

CREATE DOMAIN hive.required_automated_actions AS hive_required_automated_action[];
CREATE DOMAIN hive.optional_automated_actions AS hive_optional_automated_action[];

SELECT _variant.create_cast_in( 'hive.hive_required_automated_action[]' );
SELECT _variant.create_cast_out( 'hive.hive_required_automated_action[]' );
SELECT _variant.create_cast_in( 'hive.hive_optional_automated_action[]' );
SELECT _variant.create_cast_out( 'hive.hive_optional_automated_action[]' );

-- TODO: Move to hive schema
CREATE DOMAIN hive_block_header_extension AS variant.variant;

SELECT
  variant.register('hive_block_header_extension', '{
    hive.void_t,
    hive.version,
    hive.hardfork_version_vote,
    hive.required_automated_actions,
    hive.optional_automated_actions
}');

CREATE DOMAIN hive.block_header_extensions AS hive_block_header_extension[];

CREATE TYPE hive.signed_block_header AS (
  previous hive.block_id_type,
  "timestamp" timestamp,
  "witness" hive.account_name_type,
  transaction_merkle_root bytea,
  extensions hive.block_header_extensions,
  witness_signature hive.signature_type
);
