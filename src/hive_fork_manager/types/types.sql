-- domains

CREATE DOMAIN hive.account_name_type AS VARCHAR(16);

CREATE DOMAIN hive.permlink AS VARCHAR(255);

CREATE DOMAIN hive.comment_title AS VARCHAR(255);

CREATE DOMAIN hive.memo AS VARCHAR(2048);

CREATE DOMAIN hive.public_key_type AS VARCHAR;

CREATE DOMAIN hive.weight_type AS int4; -- uint16_t: 2 byte, but unsigned (int4)

CREATE DOMAIN hive.share_type AS int8;

CREATE DOMAIN hive.ushare_type AS NUMERIC;

CREATE DOMAIN hive.signature_type AS bytea;

CREATE DOMAIN hive.block_id_type AS bytea;

CREATE DOMAIN hive.transaction_id_type AS bytea;

CREATE DOMAIN hive.digest_type AS bytea;

CREATE DOMAIN hive.custom_id_type AS VARCHAR(32);

CREATE DOMAIN hive.asset_symbol AS int8; -- uint32_t: 4 byte, but unsigned (int8)

CREATE DOMAIN hive.proposal_subject AS VARCHAR(80);

-- assets

CREATE TYPE hive.asset AS (
  amount hive.share_type,
  precision int2,
  nai text
);

CREATE TYPE hive.price AS (
  base hive.asset,
  quote hive.asset
);

CREATE TYPE hive.legacy_hive_asset_symbol_type AS (
  ser NUMERIC
);

CREATE TYPE hive.legacy_hive_asset AS (
  amount hive.share_type,
  symbol hive.legacy_hive_asset_symbol_type
);

-- basic types

CREATE TYPE hive.hive_future_extensions AS ();

CREATE DOMAIN hive.extensions_type AS hive_future_extensions[];

CREATE TYPE hive.comment_operation AS (
  parent_author hive.account_name_type,
  parent_permlink hive.permlink,
  author hive.account_name_type,
  permlink hive.permlink,
  title hive.comment_title,
  body text,
  json_metadata jsonb
);

CREATE TYPE hive.beneficiary_route_type AS (
  account hive.account_name_type,
  weight int4 -- uint16_t: 2 byte, but unsigned (int4)
);

CREATE TYPE hive.comment_payout_beneficiaries AS (
  beneficiaries hive.beneficiary_route_type[]
);

CREATE TYPE hive.allowed_vote_assets AS (
   votable_assets hstore -- hive.asset_symbol => hive_votable_asset_info
);

CREATE TYPE hive.comment_options_extensions_type AS (
  comment_payout_beneficiaries hive.comment_payout_beneficiaries,
  allowed_vote_assets hive.allowed_vote_assets
);

CREATE TYPE hive.comment_options_operation AS (
  author hive.account_name_type,
  permlink hive.permlink,
  max_accepted_payout hive.asset,
  percent_hbd int4, -- uint16_t: 2 bytes, but unsigned (int4)
  allow_votes boolean,
  allow_curation_rewards boolean,
  extensions hive.comment_options_extensions_type
);

CREATE TYPE hive.vote_operation AS (
  voter hive.account_name_type,
  author hive.account_name_type,
  permlink hive.permlink,
  weight int4 -- uint16_t: 2 byte, but unsigned (4 byte)
);

CREATE TYPE hive.witness_set_properties_operation AS (
  owner hive.account_name_type,
  props hstore, -- text => bytea
  extensions hive.extensions_type
);

CREATE TYPE hive.authority AS (
  weight_treshold int8, -- uint32_t: 4 byte, but unsigned (int8)
  account_auths hstore, -- hive.account_name_type => hive.weight_type
  key_auths hstore -- hive.public_key_type => hive.weight_type
);

CREATE TYPE hive.account_create_operation AS (
  fee hive.asset,
  creator hive.account_name_type,
  new_account_name hive.account_name_type,
  owner hive.authority,
  active hive.authority,
  posting hive.authority,
  memo_key hive.public_key_type,
  json_metadata text
);

CREATE TYPE hive.account_create_with_delegation_operation AS (
  fee hive.asset,
  delegation hive.asset,
  creator hive.account_name_type,
  new_account_name hive.account_name_type,
  owner hive.authority,
  active hive.authority,
  posting hive.authority,
  memo_key hive.public_key_type,
  json_metadata text,
  extensions hive.extensions_type
);

CREATE TYPE hive.account_update2_operation AS (
  account hive.account_name_type,
  owner hive.authority,
  active hive.authority,
  posting hive.authority,
  memo_key hive.public_key_type,
  json_metadata text,
  posting_json_metadata text,
  extensions hive.extensions_type
);

CREATE TYPE hive.account_update_operation AS (
  account hive.account_name_type,
  owner hive.authority,
  active hive.authority,
  posting hive.authority,
  memo_key hive.public_key_type,
  json_metadata text
);

CREATE TYPE hive.account_witness_proxy_operation AS (
  account hive.account_name_type,
  proxy hive.account_name_type
);

CREATE TYPE hive.void_t AS ();
