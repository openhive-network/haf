CREATE TYPE hive.update_proposal_votes_operation AS (
  voter hive.account_name_type,
  proposal_ids NUMERIC[],
  approve boolean,
  extensions hive.extensions_type
);

SELECT _variant.create_cast_in( 'hive.update_proposal_votes_operation' );
SELECT _variant.create_cast_out( 'hive.update_proposal_votes_operation' );
