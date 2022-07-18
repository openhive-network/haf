CREATE TYPE hive._unit_smt_generation_unit AS (
  "first" hive.account_name_type,
  second int4
);

CREATE TYPE hive.smt_generation_unit AS (
  hive_unit hive._unit_smt_generation_unit[],
  token_unit hive._unit_smt_generation_unit[]
);

CREATE TYPE hive.smt_capped_generation_policy AS (
  pre_soft_cap_unit hive.smt_generation_unit,
  post_soft_cap_unit hive.smt_generation_unit,
  soft_cap_percent int4, -- uint16_t: 2 byte, but unsigned (int4)
  min_unit_ratio int8, -- uint32_t: 4 byte, but unsigned (int8)
  max_unit_ratio int8, -- uint32_t: 4 byte, but unsigned (int8)
  extensions hive.extensions_type
);
SELECT _variant.create_cast_in( 'hive.smt_capped_generation_policy' );
SELECT _variant.create_cast_out( 'hive.smt_capped_generation_policy' );

-- TODO: Move to hive schema
CREATE DOMAIN hive_smt_generation_policy AS variant.variant;
SELECT variant.register('hive_smt_generation_policy', '{ hive.smt_capped_generation_policy }');
