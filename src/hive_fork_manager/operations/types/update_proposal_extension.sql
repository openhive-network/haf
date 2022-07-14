CREATE TYPE hive.update_proposal_end_date AS (
  end_date timestamp
);
SELECT _variant.create_cast_in( 'hive.update_proposal_end_date' );
SELECT _variant.create_cast_out( 'hive.update_proposal_end_date' );

-- TODO: Move to hive schema
CREATE DOMAIN hive_update_proposal_extension AS variant.variant;
SELECT variant.register('hive_update_proposal_extension', '{
  hive.void_t,
  hive.update_proposal_end_date
}');

CREATE DOMAIN hive.update_proposal_extensions_type AS hive_update_proposal_extension[];
