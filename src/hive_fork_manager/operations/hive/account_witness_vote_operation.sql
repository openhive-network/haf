CREATE TYPE hive.account_witness_vote_operation AS (
  account hive.account_name_type,
  "witness" hive.account_name_type,
  approve boolean
);

SELECT _variant.create_cast_in( 'hive.account_witness_vote_operation' );
SELECT _variant.create_cast_out( 'hive.account_witness_vote_operation' );
