CREATE TYPE hive.smt_param_windows_v1 AS (
  cashout_window_seconds int8, -- uint32_t: 4 byte, but unsigned (int8)
  reverse_auction_window_seconds int8 -- uint32_t: 4 byte, but unsigned (int8)
);
SELECT _variant.create_cast_in( 'hive.smt_param_windows_v1' );
SELECT _variant.create_cast_out( 'hive.smt_param_windows_v1' );

CREATE TYPE hive.smt_param_vote_regeneration_period_seconds_v1 AS (
  vote_regeneration_period_seconds int8, -- uint32_t: 4 byte, but unsigned (int8)
  votes_per_regeneration_period int8 -- uint32_t: 4 byte, but unsigned (int8)
);
SELECT _variant.create_cast_in( 'hive.smt_param_vote_regeneration_period_seconds_v1' );
SELECT _variant.create_cast_out( 'hive.smt_param_vote_regeneration_period_seconds_v1' );

CREATE TYPE hive.smt_param_rewards_v1 AS (
  content_constant NUMERIC, -- uint128_t
  percent_curation_rewards int4, -- uint16_t: 2 bytes, but unsigned (int4)
  author_reward_curve hive.curve_id,
  curation_reward_curve hive.curve_id
);
SELECT _variant.create_cast_in( 'hive.smt_param_rewards_v1' );
SELECT _variant.create_cast_out( 'hive.smt_param_rewards_v1' );

CREATE TYPE hive.smt_param_allow_downvotes AS (
  "value" boolean
);
SELECT _variant.create_cast_in( 'hive.smt_param_allow_downvotes' );
SELECT _variant.create_cast_out( 'hive.smt_param_allow_downvotes' );

-- TODO: Move to hive schema
CREATE DOMAIN hive_smt_runtime_parameter AS variant.variant;
SELECT variant.register('hive_smt_runtime_parameter', '{
  hive.smt_param_windows_v1,
  hive.smt_param_vote_regeneration_period_seconds_v1,
  hive.smt_param_rewards_v1,
  hive.smt_param_allow_downvotes
}');
