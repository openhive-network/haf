#include <hive/plugins/sql_serializer/tables_descriptions.h>
#include <hive/plugins/sql_serializer/pqxx_conversions.hpp>

namespace hive{ namespace plugins{ namespace sql_serializer {

  const char hive_blocks::TABLE[] = "hive.blocks";
  const char hive_blocks::COLS[] = "num, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger ";

  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::process_block_t& block)
  {
    return stream.write_values(block.block_number,
                               block.hash,
                               block.prev_hash,
                               block.created_at,
                               block.producer_account_id,
                               block.transaction_merkle_root,
                               block.extensions,
                               block.witness_signature,
                               block.signing_key,
                               block.hbd_interest_rate,
                               block.total_vesting_fund_hive,
                               block.total_vesting_shares,
                               block.total_reward_fund_hive,
                               block.virtual_supply,
                               block.current_supply,
                               block.current_hbd_supply,
                               block.dhf_interval_ledger);
  }

  template<> const char hive_transactions< std::vector<PSQL::processing_objects::process_transaction_t> >::TABLE[] = "hive.transactions";
  template<> const char hive_transactions< std::vector<PSQL::processing_objects::process_transaction_t> >::COLS[] = "block_num, trx_in_block, trx_hash, ref_block_num, ref_block_prefix, expiration, signature";

  template<> const char hive_transactions< container_view< std::vector<PSQL::processing_objects::process_transaction_t> > >::TABLE[] = "hive.transactions";
  template<> const char hive_transactions< container_view< std::vector<PSQL::processing_objects::process_transaction_t> > >::COLS[] = "block_num, trx_in_block, trx_hash, ref_block_num, ref_block_prefix, expiration, signature";

  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::process_transaction_t& transaction)
  {
    stream.write_values(transaction.block_number, transaction.trx_in_block, transaction.hash, transaction.ref_block_num, transaction.ref_block_prefix, transaction.expiration,
                        transaction.signature);
  }

  const char hive_transactions_multisig::TABLE[] = "hive.transactions_multisig";
  const char hive_transactions_multisig::COLS[] = "trx_hash, signature";

  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::process_transaction_multisig_t& transaction_multisig)
  {
    stream.write_values(transaction_multisig.hash, transaction_multisig.signature);
  }

  template<> const char hive_operations< container_view< std::vector<PSQL::processing_objects::process_operation_t> > >::TABLE[] = "hive.operations";
  template<> const char hive_operations< container_view< std::vector<PSQL::processing_objects::process_operation_t> > >::COLS[] = "id, trx_in_block, op_pos, timestamp, body_binary";

  template<> const char  hive_operations< std::vector<PSQL::processing_objects::process_operation_t> >::TABLE[] = "hive.operations";
  template<> const char  hive_operations< std::vector<PSQL::processing_objects::process_operation_t> >::COLS[] = "id, trx_in_block, op_pos, timestamp, body_binary";

  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::process_operation_t& operation)
  {
    stream.write_values(operation.operation_id, operation.trx_in_block, operation.op_in_trx, operation.timestamp, operation.op);
  }

  template<> const char hive_accounts<std::vector<PSQL::processing_objects::account_data_t>>::TABLE[] = "hive.accounts";
  template<> const char hive_accounts<std::vector<PSQL::processing_objects::account_data_t>>::COLS[] = "id, name, block_num";

  template<> const char hive_accounts< container_view< std::vector<PSQL::processing_objects::account_data_t> > >::TABLE[] = "hive.accounts";
  template<> const char hive_accounts< container_view< std::vector<PSQL::processing_objects::account_data_t> > >::COLS[] = "id, name, block_num";

  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::account_data_t& account)
  {
    stream.write_values( account.id, account.name, account.block_number == 0 ? fc::optional<uint32_t>() : account.block_number );
  }

  template<> const char hive_account_operations< std::vector<PSQL::processing_objects::account_operation_data_t> >::TABLE[] = "hive.account_operations";
  template<> const char hive_account_operations< std::vector<PSQL::processing_objects::account_operation_data_t> >::COLS[] = "account_id, account_op_seq_no, operation_id";

  template<> const char hive_account_operations< container_view< std::vector<PSQL::processing_objects::account_operation_data_t> > >::TABLE[] = "hive.account_operations";
  template<> const char hive_account_operations< container_view< std::vector<PSQL::processing_objects::account_operation_data_t> > >::COLS[] = "account_id, account_op_seq_no, operation_id";

  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::account_operation_data_t& account_operation)
  {
    stream.write_values(account_operation.account_id, account_operation.operation_seq_no, account_operation.operation_id);
  }


  const char hive_applied_hardforks::TABLE[] = "hive.applied_hardforks";
  const char hive_applied_hardforks::COLS[] = "hardfork_num, block_num, hardfork_vop_id";
  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::applied_hardforks_t& applied_hardfork)
  {
    stream.write_values(applied_hardfork.hardfork_num, applied_hardfork.block_number, applied_hardfork.hardfork_vop_id);
  }

}}} // namespace hive::plugins::sql_serializer


