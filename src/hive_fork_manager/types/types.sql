-- domains

DROP DOMAIN IF EXISTS hive.account_name_type CASCADE;
CREATE DOMAIN hive.account_name_type AS VARCHAR(16);

DROP DOMAIN IF EXISTS hive.permlink CASCADE;
CREATE DOMAIN hive.permlink AS VARCHAR(255);

DROP DOMAIN IF EXISTS hive.comment_title CASCADE;
CREATE DOMAIN hive.comment_title AS VARCHAR(255);

DROP DOMAIN IF EXISTS hive.memo CASCADE;
CREATE DOMAIN hive.memo AS VARCHAR(2048);

DROP DOMAIN IF EXISTS hive.public_key_type CASCADE;
CREATE DOMAIN hive.public_key_type AS VARCHAR;

DROP DOMAIN IF EXISTS hive.weight_type CASCADE;
CREATE DOMAIN hive.weight_type AS int4; -- uint16_t: 2 byte, but unsigned (int4)

DROP DOMAIN IF EXISTS hive.share_type CASCADE;
CREATE DOMAIN hive.share_type AS int8;

DROP DOMAIN IF EXISTS hive.ushare_type CASCADE;
CREATE DOMAIN hive.ushare_type AS NUMERIC;

DROP DOMAIN IF EXISTS hive.signature_type CASCADE;
CREATE DOMAIN hive.signature_type AS bytea;

DROP DOMAIN IF EXISTS hive.block_id_type CASCADE;
CREATE DOMAIN hive.block_id_type AS bytea;

DROP DOMAIN IF EXISTS hive.transaction_id_type CASCADE;
CREATE DOMAIN hive.transaction_id_type AS bytea;

DROP DOMAIN IF EXISTS hive.digest_type CASCADE;
CREATE DOMAIN hive.digest_type AS bytea;

DROP DOMAIN IF EXISTS hive.custom_id_type CASCADE;
CREATE DOMAIN hive.custom_id_type AS VARCHAR(32);

DROP DOMAIN IF EXISTS hive.asset_symbol CASCADE;
CREATE DOMAIN hive.asset_symbol AS int8; -- uint32_t: 4 byte, but unsigned (int8)

DROP DOMAIN IF EXISTS hive.proposal_subject CASCADE;
CREATE DOMAIN hive.proposal_subject AS VARCHAR(80);

-- assets

DROP TYPE IF EXISTS hive.asset CASCADE;
CREATE TYPE hive.asset AS (
  amount hive.share_type,
  precision int2,
  nai text
);

DROP TYPE IF EXISTS hive.price CASCADE;
CREATE TYPE hive.price AS (
  base hive.asset,
  quote hive.asset
);

DROP TYPE IF EXISTS hive.legacy_hive_asset_symbol_type CASCADE;
CREATE TYPE hive.legacy_hive_asset_symbol_type AS (
  ser NUMERIC
);

DROP TYPE IF EXISTS hive.legacy_hive_asset CASCADE;
CREATE TYPE hive.legacy_hive_asset AS (
  amount hive.share_type,
  precision int2,
  nai text
);

-- basic types

DROP TYPE IF EXISTS hive.hive_future_extensions CASCADE;
CREATE TYPE hive.hive_future_extensions AS ();

DROP DOMAIN IF EXISTS hive.extensions_type CASCADE;
CREATE DOMAIN hive.extensions_type AS hive_future_extensions[];

DROP TYPE IF EXISTS hive.comment_operation CASCADE;
CREATE TYPE hive.comment_operation AS (
  parent_author hive.account_name_type,
  parent_permlink hive.permlink,
  author hive.account_name_type,
  permlink hive.permlink,
  title hive.comment_title,
  body text,
  json_metadata TEXT
);

DROP TYPE IF EXISTS hive.beneficiary_route_type CASCADE;
CREATE TYPE hive.beneficiary_route_type AS (
  account hive.account_name_type,
  weight int4 -- uint16_t: 2 byte, but unsigned (int4)
);

DROP TYPE IF EXISTS hive.comment_payout_beneficiaries CASCADE;
CREATE TYPE hive.comment_payout_beneficiaries AS (
  beneficiaries hive.beneficiary_route_type[]
);

DROP DOMAIN IF EXISTS hive.asset_symbol_type CASCADE;
CREATE DOMAIN hive.asset_symbol_type AS int8; -- uint32_t: 4 byte, but unsigned (int8)

DROP TYPE IF EXISTS hive.votable_asset_info_v1 CASCADE;
CREATE TYPE hive.votable_asset_info_v1 AS (
  max_accepted_payout hive.share_type,
  allow_curation_rewards boolean
);

DROP TYPE IF EXISTS hive.votable_asset_info CASCADE;
CREATE TYPE hive.votable_asset_info AS (
  v1 hive.votable_asset_info_v1
);

DROP TYPE IF EXISTS hive.allowed_vote_asset CASCADE;
CREATE TYPE hive.allowed_vote_asset AS (
  asset_symbol_type hive.asset_symbol_type,
  votable_asset_info hive.votable_asset_info
);

DROP DOMAIN IF EXISTS hive.allowed_vote_assets CASCADE;
CREATE DOMAIN hive.allowed_vote_assets AS hive.allowed_vote_asset[];

DROP TYPE IF EXISTS hive.comment_options_extensions_type CASCADE;
CREATE TYPE hive.comment_options_extensions_type AS (
  comment_payout_beneficiaries hive.comment_payout_beneficiaries,
  allowed_vote_assets hive.allowed_vote_assets
);

DROP TYPE IF EXISTS hive.comment_options_operation CASCADE;
CREATE TYPE hive.comment_options_operation AS (
  author hive.account_name_type,
  permlink hive.permlink,
  max_accepted_payout hive.asset,
  percent_hbd int4, -- uint16_t: 2 bytes, but unsigned (int4)
  allow_votes boolean,
  allow_curation_rewards boolean,
  extensions hive.comment_options_extensions_type
);

DROP TYPE IF EXISTS hive.vote_operation CASCADE;
CREATE TYPE hive.vote_operation AS (
  voter hive.account_name_type,
  author hive.account_name_type,
  permlink hive.permlink,
  weight int4 -- uint16_t: 2 byte, but unsigned (4 byte)
);

DROP TYPE IF EXISTS hive.witness_property CASCADE;
CREATE TYPE hive.witness_property AS (
  name TEXT,
  value text
);

DROP TYPE IF EXISTS hive.witness_set_properties_operation CASCADE;
CREATE TYPE hive.witness_set_properties_operation AS (
  owner hive.account_name_type,
  props hive.witness_property[],
  extensions hive.extensions_type
);

DROP TYPE IF EXISTS hive.account_auth CASCADE;
CREATE TYPE hive.account_auth AS (
  name hive.account_name_type,
  weight hive.weight_type
);

DROP TYPE IF EXISTS hive.key_auth CASCADE;
CREATE TYPE hive.key_auth AS (
  public_key hive.public_key_type,
  weight hive.weight_type
);

DROP TYPE IF EXISTS hive.authority CASCADE;
CREATE TYPE hive.authority AS (
  weight_treshold int8, -- uint32_t: 4 byte, but unsigned (int8)
  account_auths hive.account_auth[],
  key_auths hive.key_auth[]
);

DROP TYPE IF EXISTS hive.account_create_operation CASCADE;
CREATE TYPE hive.account_create_operation AS (
  fee hive.asset,
  creator hive.account_name_type,
  new_account_name hive.account_name_type,
  owner hive.authority,
  active hive.authority,
  posting hive.authority,
  memo_key hive.public_key_type,
  json_metadata TEXT
);

DROP TYPE IF EXISTS hive.account_create_with_delegation_operation CASCADE;
CREATE TYPE hive.account_create_with_delegation_operation AS (
  fee hive.asset,
  delegation hive.asset,
  creator hive.account_name_type,
  new_account_name hive.account_name_type,
  owner hive.authority,
  active hive.authority,
  posting hive.authority,
  memo_key hive.public_key_type,
  json_metadata TEXT,
  extensions hive.extensions_type
);

DROP TYPE IF EXISTS hive.account_update2_operation CASCADE;
CREATE TYPE hive.account_update2_operation AS (
  account hive.account_name_type,
  owner hive.authority,
  active hive.authority,
  posting hive.authority,
  memo_key hive.public_key_type,
  json_metadata TEXT,
  posting_json_metadata TEXT,
  extensions hive.extensions_type
);

DROP TYPE IF EXISTS hive.account_update_operation CASCADE;
CREATE TYPE hive.account_update_operation AS (
  account hive.account_name_type,
  owner hive.authority,
  active hive.authority,
  posting hive.authority,
  memo_key hive.public_key_type,
  json_metadata TEXT
);

DROP TYPE IF EXISTS hive.account_witness_proxy_operation CASCADE;
CREATE TYPE hive.account_witness_proxy_operation AS (
  account hive.account_name_type,
  proxy hive.account_name_type
);

DROP TYPE IF EXISTS hive.account_witness_vote_operation CASCADE;
CREATE TYPE hive.account_witness_vote_operation AS (
  account hive.account_name_type,
  witness hive.account_name_type,
  approve boolean
);

DROP TYPE IF EXISTS hive.cancel_transfer_from_savings_operation CASCADE;
CREATE TYPE hive.cancel_transfer_from_savings_operation AS (
  "from" hive.account_name_type,
  request_id int8 -- uint32_t: 4 byte, but unsigned (int8)
);

DROP TYPE IF EXISTS hive.change_recovery_account_operation CASCADE;
CREATE TYPE hive.change_recovery_account_operation AS (
  account_to_recover hive.account_name_type,
  new_recovery_account hive.account_name_type,
  extensions hive.extensions_type
);

DROP TYPE IF EXISTS hive.claim_account_operation CASCADE;
CREATE TYPE hive.claim_account_operation AS (
  creator hive.account_name_type,
  fee hive.asset,
  extensions hive.extensions_type
);

DROP TYPE IF EXISTS hive.claim_reward_balance_operation CASCADE;
CREATE TYPE hive.claim_reward_balance_operation AS (
  account hive.account_name_type,
  reward_hive hive.asset,
  reward_hbd hive.asset,
  reward_vests hive.asset
);

DROP TYPE IF EXISTS hive.collateralized_convert_operation CASCADE;
CREATE TYPE hive.collateralized_convert_operation AS (
  owner hive.account_name_type,
  requestid int8, -- uint32_t: 4 byte, but unsigned (int8)
  amount hive.asset
);

DROP TYPE IF EXISTS hive.convert_operation CASCADE;
CREATE TYPE hive.convert_operation AS (
  "owner" hive.account_name_type,
  requestid int8, -- uint32_t: 4 byte, bute unsigned (int8)
  amount hive.asset
);

DROP TYPE IF EXISTS hive.create_claimed_account_operation CASCADE;
CREATE TYPE hive.create_claimed_account_operation AS (
  creator hive.account_name_type,
  new_account_name hive.account_name_type,
  owner hive.authority,
  active hive.authority,
  posting hive.authority,
  memo_key hive.public_key_type,
  json_metadata TEXT,
  extensions hive.extensions_type
);

DROP TYPE IF EXISTS hive.custom_binary_operation CASCADE;
CREATE TYPE hive.custom_binary_operation AS (
  required_owner_auths hive.account_name_type[],
  required_active_auths hive.account_name_type[],
  required_posting_auths hive.account_name_type[],
  required_auths hive.authority[],
  id hive.custom_id_type,
  data bytea
);

DROP TYPE IF EXISTS hive.custom_json_operation CASCADE;
CREATE TYPE hive.custom_json_operation AS (
  required_auths hive.account_name_type[],
  required_posting_auths hive.account_name_type[],
  id hive.custom_id_type,
  json TEXT
);

DROP TYPE IF EXISTS hive.custom_operation CASCADE;
CREATE TYPE hive.custom_operation AS (
  required_auths hive.account_name_type[],
  id int4, -- uint16_t: 2 byte, but unsigned (uint16_t)
  data bytea
);

DROP TYPE IF EXISTS hive.decline_voting_rights_operation CASCADE;
CREATE TYPE hive.decline_voting_rights_operation AS (
  account hive.account_name_type,
  decline boolean
);

DROP TYPE IF EXISTS hive.delegate_vesting_shares_operation CASCADE;
CREATE TYPE hive.delegate_vesting_shares_operation AS (
  delegator hive.account_name_type,
  delegatee hive.account_name_type,
  vesting_shares hive.asset
);

DROP TYPE IF EXISTS hive.delete_comment_operation CASCADE;
CREATE TYPE hive.delete_comment_operation AS (
  author hive.account_name_type,
  permlink hive.permlink
);

DROP TYPE IF EXISTS hive.escrow_approve_operation CASCADE;
CREATE TYPE hive.escrow_approve_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  agent hive.account_name_type,
  who hive.account_name_type,
  escrow_id int8, -- uint32_t: 4 byte, but unsigned (int8)
  approve boolean
);

DROP TYPE IF EXISTS hive.escrow_dispute_operation CASCADE;
CREATE TYPE hive.escrow_dispute_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  agent hive.account_name_type,
  who hive.account_name_type,
  escrow_id int8 -- uint32_t: 4 byte, but unsigned (int8)
);

DROP TYPE IF EXISTS hive.escrow_release_operation CASCADE;
CREATE TYPE hive.escrow_release_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  agent hive.account_name_type,
  who hive.account_name_type,
  receiver hive.account_name_type,
  escrow_id int8, -- uint32_t: 4 byte, but unsigned (int8)
  hbd_amount hive.asset,
  hive_amount hive.asset
);

DROP TYPE IF EXISTS hive.escrow_transfer_operation CASCADE;
CREATE TYPE hive.escrow_transfer_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  hbd_amount hive.asset,
  hive_amount hive.asset,
  escrow_id int8, -- uint32_t: 4 byte, but unsigned (int8)
  agent hive.account_name_type,
  fee hive.asset,
  json_meta TEXT,
  ratification_deadline timestamp,
  escrow_expiration timestamp
);

DROP TYPE IF EXISTS hive.feed_publish_operation CASCADE;
CREATE TYPE hive.feed_publish_operation AS (
  publisher hive.account_name_type,
  exchange_rate hive.price
);

DROP TYPE IF EXISTS hive.limit_order_cancel_operation CASCADE;
CREATE TYPE hive.limit_order_cancel_operation AS (
  owner hive.account_name_type,
  orderid int8 -- uint32_t: 4 byte, but unsigned (int8)
);

DROP TYPE IF EXISTS hive.limit_order_create2_operation CASCADE;
CREATE TYPE hive.limit_order_create2_operation AS (
  owner hive.account_name_type,
  orderid int8, -- uint32_t: 4 byte, but unsigned (int8)
  amount_to_sell hive.asset,
  exchange_rate hive.price,
  fill_or_kill boolean,
  expiration timestamp
);

DROP TYPE IF EXISTS hive.limit_order_create_operation CASCADE;
CREATE TYPE hive.limit_order_create_operation AS (
  owner hive.account_name_type,
  orderid int8, -- uint32_t: 4 byte, but unsigned (int8)
  amount_to_sell hive.asset,
  min_to_receive hive.asset,
  fill_or_kill boolean,
  expiration timestamp
);

DROP TYPE IF EXISTS hive.pow2_input CASCADE;
CREATE TYPE hive.pow2_input AS (
  worker_account hive.account_name_type,
  prev_block hive.block_id_type,
  nonce NUMERIC
);

DROP TYPE IF EXISTS hive.pow2 CASCADE;
CREATE TYPE hive.pow2 AS (
  input hive.pow2_input,
  pow_summary int8 -- uint32_t: 4 byte, but unsigned (int8)
);

DROP TYPE IF EXISTS hive.proof CASCADE;
CREATE TYPE hive.proof AS (
      n int8,
      k int8,
      seed TEXT,
      inputs int8[]
);

DROP TYPE IF EXISTS hive.equihash_pow CASCADE;
CREATE TYPE hive.equihash_pow AS (
  input hive.pow2_input,
  proof hive.proof,
  prev_block hive.block_id_type,
  pow_summary int8 -- uint32_t: 4 byte, but unsigned (int8)
);

DROP TYPE IF EXISTS hive.pow2_work CASCADE;
CREATE TYPE hive.pow2_work AS (
  pow2 hive.pow2,
  equihash_pow hive.equihash_pow
);

DROP TYPE IF EXISTS hive.legacy_chain_properties CASCADE;
CREATE TYPE hive.legacy_chain_properties AS (
  account_creation_fee hive.legacy_hive_asset,
  maximum_block_size int8, -- uint32_t: 4 byte, but unsigned (int8)
  hbd_interest_rate int4 -- uint16_t: 2 byte, but unsigned (int4)
);

DROP TYPE IF EXISTS hive.pow2_operation CASCADE;
CREATE TYPE hive.pow2_operation AS (
  work hive.pow2_work,
  new_owner_key hive.public_key_type,
  props hive.legacy_chain_properties
);

DROP TYPE IF EXISTS pow CASCADE;
CREATE TYPE pow AS (
  worker hive.public_key_type,
  input hive.digest_type,
  signature hive.signature_type,
  work hive.digest_type
);

DROP TYPE IF EXISTS hive.pow_operation CASCADE;
CREATE TYPE hive.pow_operation AS (
  worker_account hive.account_name_type,
  block_id hive.block_id_type,
  nonce NUMERIC,
  work hive.pow,
  props hive.legacy_chain_properties
);

DROP TYPE IF EXISTS hive.recover_account_operation CASCADE;
CREATE TYPE hive.recover_account_operation AS (
  account_to_recover hive.account_name_type,
  new_owner_authority hive.authority,
  recent_owner_authority hive.authority,
  extensions hive.extensions_type
);

DROP TYPE IF EXISTS hive.recurrent_transfer_pair_id CASCADE;
CREATE TYPE hive.recurrent_transfer_pair_id AS (
  pair_id int2 -- uint8_t: 1 byte, but unsigned (int2)
);

DROP TYPE IF EXISTS hive.recurrent_transfer_extensions_type CASCADE;
CREATE TYPE hive.recurrent_transfer_extensions_type AS (
  recurrent_transfer_pair_id hive.recurrent_transfer_pair_id
);

DROP TYPE IF EXISTS hive.recurrent_transfer_operation CASCADE;
CREATE TYPE hive.recurrent_transfer_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  amount hive.asset,
  memo hive.memo,
  recurrence int4, -- uint16_t: 2 byte, but unsigned (int4)
  executions int4, -- uint16_t: 2 byte, but unsigned (int4)
  extensions hive.recurrent_transfer_extensions_type
);

DROP TYPE IF EXISTS hive.request_account_recovery_operation CASCADE;
CREATE TYPE hive.request_account_recovery_operation AS (
  recovery_account hive.account_name_type,
  account_to_recover hive.account_name_type,
  new_owner_authority hive.authority,
  extensions hive.extensions_type
);

DROP TYPE IF EXISTS hive.reset_account_operation CASCADE;
CREATE TYPE hive.reset_account_operation AS (
  reset_account hive.account_name_type,
  account_to_reset hive.account_name_type,
  new_owner_authority hive.authority
);

DROP TYPE IF EXISTS hive.set_reset_account_operation CASCADE;
CREATE TYPE hive.set_reset_account_operation AS (
  account hive.account_name_type,
  current_reset_account hive.account_name_type,
  reset_account hive.account_name_type
);

DROP TYPE IF EXISTS hive.set_withdraw_vesting_route_operation CASCADE;
CREATE TYPE hive.set_withdraw_vesting_route_operation AS (
  from_account hive.account_name_type,
  to_account hive.account_name_type,
  percent int4, -- uint16_t: 4 byte, but unsigned (int4)
  auto_vest boolean
);

DROP TYPE IF EXISTS hive.transfer_from_savings_operation CASCADE;
CREATE TYPE hive.transfer_from_savings_operation AS (
  "from" hive.account_name_type,
  request_id int8, -- uint32_t: 4 byte, but unsigned (int8)
  "to" hive.account_name_type,
  amount hive.asset,
  memo hive.memo
);

DROP TYPE IF EXISTS hive.transfer_operation CASCADE;
CREATE TYPE hive.transfer_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  amount hive.asset,
  memo hive.memo
);

DROP TYPE IF EXISTS hive.transfer_to_savings_operation CASCADE;
CREATE TYPE hive.transfer_to_savings_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  amount hive.asset,
  memo hive.memo
);

DROP TYPE IF EXISTS hive.transfer_to_vesting_operation CASCADE;
CREATE TYPE hive.transfer_to_vesting_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  amount hive.asset
);

DROP TYPE IF EXISTS hive.withdraw_vesting_operation CASCADE;
CREATE TYPE hive.withdraw_vesting_operation AS (
  "to" hive.account_name_type,
  vesting_shares hive.asset
);

DROP TYPE IF EXISTS hive.witness_update_operation CASCADE;
CREATE TYPE hive.witness_update_operation AS (
  owner hive.account_name_type,
  url hive.permlink,
  block_signing_key hive.public_key_type,
  props hive.legacy_chain_properties,
  fee hive.asset
);

DROP TYPE IF EXISTS hive.create_proposal_operation CASCADE;
CREATE TYPE hive.create_proposal_operation AS (
  creator hive.account_name_type,
  receiver hive.account_name_type,
  start_date timestamp,
  end_date timestamp,
  daily_pay hive.asset,
  subject TEXT,
  permlink TEXT,
  extensions hive.extensions_type
);

DROP TYPE IF EXISTS hive.proposal_pay_operation CASCADE;
CREATE TYPE hive.proposal_pay_operation AS (
  proposal_id int8, -- uint32_t: 4 bytes, but unsigned (int8)
  receiver hive.account_name_type,
  payer hive.account_name_type,
  payment hive.asset
);

DROP TYPE IF EXISTS hive.remove_proposal_operation CASCADE;
CREATE TYPE hive.remove_proposal_operation AS (
  proposal_owner hive.account_name_type,
  proposal_ids int8[],
  extensions hive.extensions_type
);

DROP TYPE IF EXISTS hive.update_proposal_end_date CASCADE;
CREATE TYPE hive.update_proposal_end_date AS (
  end_date timestamp
);

DROP TYPE IF EXISTS hive.update_proposal_extensions_type CASCADE;
CREATE TYPE hive.update_proposal_extensions_type AS (
  update_proposal_end_date hive.update_proposal_end_date
);

DROP TYPE IF EXISTS hive.update_proposal_operation CASCADE;
CREATE TYPE hive.update_proposal_operation AS (
  proposal_id int8,
  creator hive.account_name_type,
  daily_pay hive.asset,
  subject hive.proposal_subject,
  permlink hive.permlink,
  extensions hive.update_proposal_extensions_type
);

DROP TYPE IF EXISTS hive.update_proposal_votes_operation CASCADE;
CREATE TYPE hive.update_proposal_votes_operation AS (
  voter hive.account_name_type,
  proposal_ids int8[],
  approve boolean,
  extensions hive.extensions_type
);

DROP TYPE IF EXISTS hive.account_created_operation CASCADE;
CREATE TYPE hive.account_created_operation AS (
  new_account_name hive.account_name_type,
  creator hive.account_name_type,
  initial_vesting_shares hive.asset,
  initial_delegation hive.asset
);

DROP TYPE IF EXISTS hive.author_reward_operation CASCADE;
CREATE TYPE hive.author_reward_operation AS (
  author hive.account_name_type,
  permlink hive.permlink,
  hbd_payout hive.asset,
  hive_payout hive.asset,
  vesting_payout hive.asset,
  curators_vesting_payout hive.asset,
  payout_must_be_claimed boolean
);

DROP TYPE IF EXISTS hive.changed_recovery_account_operation CASCADE;
CREATE TYPE hive.changed_recovery_account_operation AS (
  account hive.account_name_type,
  old_recovery_account hive.account_name_type,
  new_recovery_account hive.account_name_type
);

DROP TYPE IF EXISTS hive.clear_null_account_balance_operation CASCADE;
CREATE TYPE hive.clear_null_account_balance_operation AS (
  total_cleared hive.asset[]
);

DROP TYPE IF EXISTS hive.comment_benefactor_reward_operation CASCADE;
CREATE TYPE hive.comment_benefactor_reward_operation AS (
  benefactor hive.account_name_type,
  author hive.account_name_type,
  permlink hive.permlink,
  hbd_payout hive.asset,
  hive_payout hive.asset,
  vesting_payout hive.asset,
  payout_must_be_claimed BOOL
);

DROP TYPE IF EXISTS hive.comment_payout_update_operation CASCADE;
CREATE TYPE hive.comment_payout_update_operation AS (
  author hive.account_name_type,
  permlink hive.permlink
);

DROP TYPE IF EXISTS hive.comment_reward_operation CASCADE;
CREATE TYPE hive.comment_reward_operation AS (
  author hive.account_name_type,
  permlink hive.permlink,
  payout hive.asset,
  author_rewards hive.share_type,
  total_payout_value hive.asset,
  curator_payout_value hive.asset,
  beneficiary_payout_value hive.asset
);

DROP TYPE IF EXISTS hive.consolidate_treasury_balance_operation CASCADE;
CREATE TYPE hive.consolidate_treasury_balance_operation AS (
  total_moved hive.asset[]
);

DROP TYPE IF EXISTS hive.curation_reward_operation CASCADE;
CREATE TYPE hive.curation_reward_operation AS (
  curator hive.account_name_type,
  reward hive.asset,
  comment_author hive.account_name_type,
  comment_permlink hive.permlink,
  payout_must_be_claimed boolean
);

DROP TYPE IF EXISTS hive.delayed_voting_operation CASCADE;
CREATE TYPE hive.delayed_voting_operation AS (
  voter hive.account_name_type,
  votes hive.ushare_type
);

DROP TYPE IF EXISTS hive.effective_comment_vote_operation CASCADE;
CREATE TYPE hive.effective_comment_vote_operation AS (
  voter hive.account_name_type,
  author hive.account_name_type,
  permlink hive.permlink,
  weight NUMERIC,
  rshares int8,
  total_vote_weight NUMERIC,
  pending_payout hive.asset
);

DROP TYPE IF EXISTS hive.expired_account_notification_operation CASCADE;
CREATE TYPE hive.expired_account_notification_operation AS (
  account hive.account_name_type
);

DROP TYPE IF EXISTS hive.failed_recurrent_transfer_operation CASCADE;
CREATE TYPE hive.failed_recurrent_transfer_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  amount hive.asset,
  memo hive.memo,
  consecutive_failures int2, -- uint8_t: 1 byte, but unsigned (int2)
  remaining_executions int4, -- uint16_t: 2 bytes, but unsigned (int4)
  deleted boolean
);

DROP TYPE IF EXISTS hive.fill_collateralized_convert_request_operation CASCADE;
CREATE TYPE hive.fill_collateralized_convert_request_operation AS (
  owner hive.account_name_type,
  requestid int8, -- uint32_t: 4 bytes, but unsigned (int8)
  amount_in hive.asset,
  amount_out hive.asset,
  excess_collateral hive.asset
);

DROP TYPE IF EXISTS hive.fill_convert_request_operation CASCADE;
CREATE TYPE hive.fill_convert_request_operation AS (
  owner hive.account_name_type,
  requestid int8, -- uint32_t: 4 bytes, but unsigned (int8)
  amount_in hive.asset,
  amount_out hive.asset
);

DROP TYPE IF EXISTS hive.fill_order_operation CASCADE;
CREATE TYPE hive.fill_order_operation AS (
  current_owner hive.account_name_type,
  current_orderid int8, -- uint32_t: 4 bytes, but unsigned (int8)
  current_pays hive.asset,
  open_owner hive.account_name_type,
  open_orderid int8, -- uint32_t: 4 bytes, but unsigned (int8)
  open_pays hive.asset
);

DROP TYPE IF EXISTS hive.fill_recurrent_transfer_operation CASCADE;
CREATE TYPE hive.fill_recurrent_transfer_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  amount hive.asset,
  memo hive.memo,
  remaining_executions int4 -- uint16_t: 2 bytes, but unsigned (int4)
);

DROP TYPE IF EXISTS hive.fill_transfer_from_savings_operation CASCADE;
CREATE TYPE hive.fill_transfer_from_savings_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  amount hive.asset,
  request_id int8, -- uint32_t: 4 bytes, but unsigned (int8)
  memo hive.memo
);

DROP TYPE IF EXISTS hive.fill_vesting_withdraw_operation CASCADE;
CREATE TYPE hive.fill_vesting_withdraw_operation AS (
  from_account hive.account_name_type,
  to_account hive.account_name_type,
  withdrawn hive.asset,
  deposited hive.asset
);

DROP TYPE IF EXISTS hive.hardfork_hive_operation CASCADE;
CREATE TYPE hive.hardfork_hive_operation AS (
  account hive.account_name_type,
  treasury hive.account_name_type,
  other_affected_accounts hive.account_name_type[],
  hbd_transferred hive.asset,
  hive_transferred hive.asset,
  vests_converted hive.asset,
  total_hive_from_vests hive.asset
);

DROP TYPE IF EXISTS hive.hardfork_hive_restore_operation CASCADE;
CREATE TYPE hive.hardfork_hive_restore_operation AS (
  account hive.account_name_type,
  treasury hive.account_name_type,
  hbd_transferred hive.asset,
  hive_transferred hive.asset
);

DROP TYPE IF EXISTS hive.hardfork_operation CASCADE;
CREATE TYPE hive.hardfork_operation AS (
  hardfork_id int8 -- uint32_t: 4 bytes, but unsigned (int8)
);

DROP TYPE IF EXISTS hive.ineffective_delete_comment_operation CASCADE;
CREATE TYPE hive.ineffective_delete_comment_operation AS (
  author hive.account_name_type,
  permlink hive.permlink
);

DROP TYPE IF EXISTS hive.interest_operation CASCADE;
CREATE TYPE hive.interest_operation AS (
  owner hive.account_name_type,
  interest hive.asset,
  is_saved_into_hbd_balance BOOL
);

DROP TYPE IF EXISTS hive.limit_order_cancelled_operation CASCADE;
CREATE TYPE hive.limit_order_cancelled_operation AS (
  seller hive.account_name_type,
  orderid int4, -- uint16_t: 2 bytes, but unsigned (int4)
  amount_back hive.asset
);

DROP TYPE IF EXISTS hive.liquidity_reward_operation CASCADE;
CREATE TYPE hive.liquidity_reward_operation AS (
  "owner" hive.account_name_type,
  payout hive.asset
);

DROP TYPE IF EXISTS hive.pow_reward_operation CASCADE;
CREATE TYPE hive.pow_reward_operation AS (
  worker hive.account_name_type,
  reward hive.asset
);

DROP TYPE IF EXISTS hive.producer_reward_operation CASCADE;
CREATE TYPE hive.producer_reward_operation AS (
  producer hive.account_name_type,
  vesting_shares hive.asset
);

DROP TYPE IF EXISTS hive.return_vesting_delegation_operation CASCADE;
CREATE TYPE hive.return_vesting_delegation_operation AS (
  account hive.account_name_type,
  vesting_shares hive.asset
);

DROP TYPE IF EXISTS hive.shutdown_witness_operation CASCADE;
CREATE TYPE hive.shutdown_witness_operation AS (
  "owner" hive.account_name_type
);

DROP TYPE IF EXISTS hive.system_warning_operation CASCADE;
CREATE TYPE hive.system_warning_operation AS (
  message text
);

DROP TYPE IF EXISTS hive.transfer_to_vesting_completed_operation CASCADE;
CREATE TYPE hive.transfer_to_vesting_completed_operation AS (
  from_account hive.account_name_type,
  to_account hive.account_name_type,
  hive_vested hive.asset,
  vesting_shares_received hive.asset
);

DROP TYPE IF EXISTS hive.vesting_shares_split_operation CASCADE;
CREATE TYPE hive.vesting_shares_split_operation AS (
  "owner" hive.account_name_type,
  vesting_shares_before_split hive.asset,
  vesting_shares_after_split hive.asset
);

DROP TYPE IF EXISTS hive.witness_block_approve_operation CASCADE;
CREATE TYPE hive.witness_block_approve_operation AS (
  witness hive.account_name_type,
  block_id hive.block_id_type
);

DROP TYPE IF EXISTS hive.dhf_funding_operation CASCADE;
CREATE TYPE hive.dhf_funding_operation AS (
  treasury hive.account_name_type,
  additional_funds hive.asset
);

DROP TYPE IF EXISTS hive.dhf_conversion_operation CASCADE;
CREATE TYPE hive.dhf_conversion_operation AS (
  treasury hive.account_name_type,
  hive_amount_in hive.asset,
  hbd_amount_out hive.asset
);

DROP TYPE IF EXISTS hive.producer_missed_operation CASCADE;
CREATE TYPE hive.producer_missed_operation AS (
  producer hive.account_name_type
);

DROP TYPE IF EXISTS hive.proposal_fee_operation CASCADE;
CREATE TYPE hive.proposal_fee_operation AS (
  creator hive.account_name_type,
  treasury hive.account_name_type,
  proposal_id int8, -- uint32_t: 4 bytes, but unsigned (int8)
  fee hive.asset
);

DROP TYPE IF EXISTS hive.collateralized_convert_immediate_conversion_operation CASCADE;
CREATE TYPE hive.collateralized_convert_immediate_conversion_operation AS (
  owner hive.account_name_type,
  requestid int8, -- uint32_t: 4 bytes, but unsigned (int8)
  hbd_out hive.asset
);

DROP TYPE IF EXISTS hive.escrow_approved_operation CASCADE;
CREATE TYPE hive.escrow_approved_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  agent hive.account_name_type,
  escrow_id int8, -- uint32_t: 4 bytes, but unsigned (int8)
  fee hive.asset
);

DROP TYPE IF EXISTS hive.escrow_rejected_operation CASCADE;
CREATE TYPE hive.escrow_rejected_operation AS (
  "from" hive.account_name_type,
  "to" hive.account_name_type,
  agent hive.account_name_type,
  escrow_id int8, -- uint32_t: 4 bytes, but unsigned (int8)
  hbd_amount hive.asset,
  hive_amount hive.asset,
  fee hive.asset
);

DROP TYPE IF EXISTS hive.proxy_cleared_operation CASCADE;
CREATE TYPE hive.proxy_cleared_operation AS (
  account hive.account_name_type,
  proxy hive.account_name_type
);

DROP TYPE IF EXISTS hive.declined_voting_rights_operation CASCADE;
CREATE TYPE hive.declined_voting_rights_operation AS (
  account hive.account_name_type
);

DROP TYPE IF EXISTS hive.void_t CASCADE;
CREATE TYPE hive.void_t AS ();
