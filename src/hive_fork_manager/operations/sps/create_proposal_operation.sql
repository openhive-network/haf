CREATE TYPE hive.create_proposal_operation AS (
  proposal_owner hive.account_name_type,
  proposal_ids NUMERIC[],
  extensions hive.extensions_type
);

SELECT _variant.create_cast_in( 'hive.create_proposal_operation' );
SELECT _variant.create_cast_out( 'hive.create_proposal_operation' );
