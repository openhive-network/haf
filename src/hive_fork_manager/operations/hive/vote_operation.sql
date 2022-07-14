CREATE TYPE hive.vote_operation AS (
  voter hive.account_name_type,
  author hive.account_name_type,
  permlink hive.permlink,
  "weight" int4 -- uint16_t: 2 byte, but unsigned (4 byte)
);

SELECT _variant.create_cast_in( 'hive.vote_operation' );
SELECT _variant.create_cast_out( 'hive.vote_operation' );
