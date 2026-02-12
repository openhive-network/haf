#include <hive/plugins/sql_serializer/tables_descriptions.h>
#include <hive/plugins/sql_serializer/pqxx_conversions.hpp>

namespace hive{ namespace plugins{ namespace sql_serializer {

  const char hive_blocks::TABLE[] = "hafd.blocks";
  const char hive_blocks::COLS[] = "block_id, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger ";

  // Convert block_number to block_id: block_id = (block_num << 32) | fork_id
  // During massive sync, fork_id is always 0
  inline int64_t make_block_id(int32_t block_num, int32_t fork_id = 0) {
    return (static_cast<int64_t>(block_num) << 32) | static_cast<int64_t>(fork_id);
  }

  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::process_block_t& block)
  {
    return stream.write_values(make_block_id(block.block_number),
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

  // Transactions - uses block_id for fork tracking
  template<> const char hive_transactions< std::vector<PSQL::processing_objects::process_transaction_t> >::TABLE[] = "hafd.transactions";
  template<> const char hive_transactions< std::vector<PSQL::processing_objects::process_transaction_t> >::COLS[] = "block_id, trx_in_block, trx_hash, ref_block_num, ref_block_prefix, expiration, signature";

  template<> const char hive_transactions< container_view< std::vector<PSQL::processing_objects::process_transaction_t> > >::TABLE[] = "hafd.transactions";
  template<> const char hive_transactions< container_view< std::vector<PSQL::processing_objects::process_transaction_t> > >::COLS[] = "block_id, trx_in_block, trx_hash, ref_block_num, ref_block_prefix, expiration, signature";

  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::process_transaction_t& transaction)
  {
    stream.write_values(make_block_id(transaction.block_number), transaction.trx_in_block, transaction.hash, transaction.ref_block_num, transaction.ref_block_prefix, transaction.expiration,
                        transaction.signature);
  }

  // Transactions multisig - uses block_id for fork tracking
  const char hive_transactions_multisig::TABLE[] = "hafd.transactions_multisig";
  const char hive_transactions_multisig::COLS[] = "trx_hash, signature, block_id";

  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::process_transaction_multisig_t& transaction_multisig)
  {
    stream.write_values(transaction_multisig.hash, transaction_multisig.signature, make_block_id(transaction_multisig.block_number));
  }

  // Operations - uses block_id and pre-computed id for performance
  // seq_in_block and op_type_id can be extracted from id using hafd.operation_id_to_pos() and hafd.operation_id_to_type_id()
  template<> const char hive_operations< container_view< std::vector<PSQL::processing_objects::process_operation_t> > >::TABLE[] = "hafd.operations";
  template<> const char hive_operations< container_view< std::vector<PSQL::processing_objects::process_operation_t> > >::COLS[] = "block_id, trx_in_block, op_pos, body_binary, id";

  template<> const char  hive_operations< std::vector<PSQL::processing_objects::process_operation_t> >::TABLE[] = "hafd.operations";
  template<> const char  hive_operations< std::vector<PSQL::processing_objects::process_operation_t> >::COLS[] = "block_id, trx_in_block, op_pos, body_binary, id";

  // id encoding: (block_num << 32) | (seq_in_block << 8) | op_type_id
  // id is passed directly from operation.operation_id (pre-computed for performance)
  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::process_operation_t& operation)
  {
    int32_t block_num = static_cast<int32_t>(operation.operation_id >> 32);
    stream.write_values(make_block_id(block_num), operation.trx_in_block, operation.op_in_trx, operation.op, operation.operation_id);
  }

  // Accounts - uses block_id for fork tracking
  template<> const char hive_accounts<std::vector<PSQL::processing_objects::account_data_t>>::TABLE[] = "hafd.accounts";
  template<> const char hive_accounts<std::vector<PSQL::processing_objects::account_data_t>>::COLS[] = "id, name, block_id";

  template<> const char hive_accounts< container_view< std::vector<PSQL::processing_objects::account_data_t> > >::TABLE[] = "hafd.accounts";
  template<> const char hive_accounts< container_view< std::vector<PSQL::processing_objects::account_data_t> > >::COLS[] = "id, name, block_id";

  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::account_data_t& account)
  {
    // For accounts with block_number == 0 (dumped at startup when psql-first-block > 1),
    // write NULL since the creation block is unknown/not stored
    stream.write_values(account.id, account.name, account.block_number == 0 ? fc::optional<int64_t>() : make_block_id(account.block_number));
  }

  // Account operations - uses block_id and operation_id for direct join to operations
  template<> const char hive_account_operations< std::vector<PSQL::processing_objects::account_operation_data_t> >::TABLE[] = "hafd.account_operations";
  template<> const char hive_account_operations< std::vector<PSQL::processing_objects::account_operation_data_t> >::COLS[] = "account_id, transacting_account_id, account_op_seq_no, block_id, operation_id";

  template<> const char hive_account_operations< container_view< std::vector<PSQL::processing_objects::account_operation_data_t> > >::TABLE[] = "hafd.account_operations";
  template<> const char hive_account_operations< container_view< std::vector<PSQL::processing_objects::account_operation_data_t> > >::COLS[] = "account_id, transacting_account_id, account_op_seq_no, block_id, operation_id";

  // Write account_operation with block_id and full operation_id for efficient join to operations table
  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::account_operation_data_t& account_operation)
  {
    int32_t block_num = static_cast<int32_t>(account_operation.operation_id >> 32);

    stream.write_values(account_operation.account_id, account_operation.transacting_account_id, account_operation.operation_seq_no, make_block_id(block_num), account_operation.operation_id);
  }

  // Applied hardforks - uses block_id for fork tracking
  const char hive_applied_hardforks::TABLE[] = "hafd.applied_hardforks";
  const char hive_applied_hardforks::COLS[] = "hardfork_num, block_id, hardfork_vop_id";
  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::applied_hardforks_t& applied_hardfork)
  {
    stream.write_values(applied_hardfork.hardfork_num, make_block_id(applied_hardfork.block_number), applied_hardfork.hardfork_vop_id);
  }

}}} // namespace hive::plugins::sql_serializer
