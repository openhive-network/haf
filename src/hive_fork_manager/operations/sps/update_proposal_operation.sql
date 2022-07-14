CREATE TYPE hive.update_proposal_operation AS (
  proposal_id NUMERIC,
  creator hive.account_name_type,
  daily_pay hive.asset,
  "subject" hive.proposal_subject,
  permlink hive.permlink,
  extensions hive.update_proposal_extensions_type
);

SELECT _variant.create_cast_in( 'hive.update_proposal_operation' );
SELECT _variant.create_cast_out( 'hive.update_proposal_operation' );
