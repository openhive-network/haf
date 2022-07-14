CREATE TYPE hive.decline_voting_rights_operation AS (
  account hive.account_name_type,
  decline boolean
);

SELECT _variant.create_cast_in( 'hive.decline_voting_rights_operation' );
SELECT _variant.create_cast_out( 'hive.decline_voting_rights_operation' );
