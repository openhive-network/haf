CREATE TYPE hive.beneficiary_route_type AS (
  account hive.account_name_type,
  "weight" int4 -- uint16_t: 2 byte, but unsigned (int4)
);

CREATE TYPE hive.comment_payout_beneficiaries AS (
  beneficiaries hive.beneficiary_route_type[]
);
SELECT _variant.create_cast_in( 'hive.comment_payout_beneficiaries' );
SELECT _variant.create_cast_out( 'hive.comment_payout_beneficiaries' );

CREATE TYPE hive.votable_asset_info_v1 AS (
  max_accepted_payout hive.share_type,
  allow_curation_rewards boolean
);
SELECT _variant.create_cast_in( 'hive.votable_asset_info_v1' );
SELECT _variant.create_cast_out( 'hive.votable_asset_info_v1' );
-- TODO: Move to hive schema
CREATE DOMAIN hive_votable_asset_info AS variant.variant;
SELECT variant.register('hive_votable_asset_info', '{ hive.votable_asset_info_v1 }');

CREATE TYPE hive._votable_asset_allowed_vote_assets AS (
  "first" hive.asset_symbol,
  second hive_votable_asset_info
);

CREATE TYPE hive.allowed_vote_assets AS (
   votable_assets hive._votable_asset_allowed_vote_assets[]
);
SELECT _variant.create_cast_in( 'hive.allowed_vote_assets' );
SELECT _variant.create_cast_out( 'hive.allowed_vote_assets' );

-- TODO: Move to hive schema
CREATE DOMAIN hive_comment_options_extension AS variant.variant;
SELECT variant.register('hive_comment_options_extension', '{
  hive.comment_payout_beneficiaries,
  hive.allowed_vote_assets
}');

CREATE DOMAIN hive.comment_options_extensions_type AS hive_comment_options_extension[];
