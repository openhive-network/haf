CREATE TYPE hive.smt_param_allow_voting AS (
  "value" boolean
);
SELECT _variant.create_cast_in( 'hive.smt_param_allow_voting' );
SELECT _variant.create_cast_out( 'hive.smt_param_allow_voting' );

-- TODO: Move to hive schema
CREATE DOMAIN hive_smt_setup_parameter AS variant.variant;
SELECT variant.register('hive_smt_setup_parameter', '{ hive.smt_param_allow_voting }');
