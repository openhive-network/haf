#include <hive/plugins/sql_serializer/tables_descriptions.h>

namespace hive{ namespace plugins{ namespace sql_serializer {

  const char hive_blocks::TABLE[] = "hive.blocks";
  const char hive_blocks::COLS[] = "num, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger ";
  const char* const hive_blocks::COLS_ARRAY[] = {"num", "hash", "prev", "created_at", "producer_account_id", "transaction_merkle_root", "extensions", "witness_signature", "signing_key", "hbd_interest_rate", "total_vesting_fund_hive", "total_vesting_shares", "total_reward_fund_hive", "virtual_supply", "current_supply", "current_hbd_supply", "dhf_interval_ledger"};
  static_assert(hive_blocks::COLS_ARRAY_LEN == sizeof(hive_blocks::COLS_ARRAY) / sizeof(hive_blocks::COLS_ARRAY[0]), "incorrect size of hive_blocks::COLS_ARRAY");

  std::tuple<int, fc::ripemd160, fc::ripemd160, fc::time_point_sec,
             int32_t, fc::ripemd160, fc::optional<std::string>, fc::ecc::compact_signature, 
             std::string, uint16_t, std::string, std::string, 
             std::string, std::string, std::string, std::string, 
             std::string>
    to_tuple(const PSQL::processing_objects::process_block_t& block)
  {
    return std::make_tuple(block.block_number,
                           block.hash,
                           block.prev_hash,
                           block.created_at,

                           block.producer_account_id,
                           block.transaction_merkle_root,
                           block.extensions,
                           block.witness_signature,

                           (std::string)block.signing_key,
                           block.hbd_interest_rate,
                           std::to_string(block.total_vesting_fund_hive.amount.value),
                           std::to_string(block.total_vesting_shares.amount.value),

                           std::to_string(block.total_reward_fund_hive.amount.value),
                           std::to_string(block.virtual_supply.amount.value),
                           std::to_string(block.current_supply.amount.value),
                           std::to_string(block.current_hbd_supply.amount.value),

                           std::to_string(block.dhf_interval_ledger.amount.value));
  }
  

  template<> const char hive_transactions< std::vector<PSQL::processing_objects::process_transaction_t> >::TABLE[] = "hive.transactions";
  template<> const char hive_transactions< std::vector<PSQL::processing_objects::process_transaction_t> >::COLS[] = "block_num, trx_in_block, trx_hash, ref_block_num, ref_block_prefix, expiration, signature";
  template<> const char* const hive_transactions<std::vector<PSQL::processing_objects::process_transaction_t>>::COLS_ARRAY[] = {"block_num", "trx_in_block", "trx_hash", "ref_block_num", "ref_block_prefix", "expiration", "signature"};
  static_assert(hive_transactions<std::vector<PSQL::processing_objects::process_transaction_t>>::COLS_ARRAY_LEN == sizeof(hive_transactions<std::vector<PSQL::processing_objects::process_transaction_t>>::COLS_ARRAY) / sizeof(hive_transactions<std::vector<PSQL::processing_objects::process_transaction_t>>::COLS_ARRAY[0]), "incorrect size of hive_transactions::COLS_ARRAY");

  template<> const char hive_transactions< container_view< std::vector<PSQL::processing_objects::process_transaction_t> > >::TABLE[] = "hive.transactions";
  template<> const char hive_transactions< container_view< std::vector<PSQL::processing_objects::process_transaction_t> > >::COLS[] = "block_num, trx_in_block, trx_hash, ref_block_num, ref_block_prefix, expiration, signature";
  template<> const char* const hive_transactions<container_view<std::vector<PSQL::processing_objects::process_transaction_t>>>::COLS_ARRAY[] = {"block_num", "trx_in_block", "trx_hash", "ref_block_num", "ref_block_prefix", "expiration", "signature"};
  static_assert(hive_transactions<container_view<std::vector<PSQL::processing_objects::process_transaction_t>>>::COLS_ARRAY_LEN == sizeof(hive_transactions<container_view<std::vector<PSQL::processing_objects::process_transaction_t>>>::COLS_ARRAY) / sizeof(hive_transactions<container_view<std::vector<PSQL::processing_objects::process_transaction_t>>>::COLS_ARRAY[0]), "incorrect size of hive_transactions::COLS_ARRAY");

  std::tuple<int, int32_t, fc::ripemd160, uint16_t, uint32_t, fc::time_point_sec, fc::optional<fc::ecc::compact_signature>> to_tuple(const PSQL::processing_objects::process_transaction_t& transaction)
  {
    return std::make_tuple(transaction.block_number,
                           transaction.trx_in_block,
                           transaction.hash,
                           transaction.ref_block_num,
                           transaction.ref_block_prefix, 
                           transaction.expiration,
                           transaction.signature);
  }

  const char hive_transactions_multisig::TABLE[] = "hive.transactions_multisig";
  const char hive_transactions_multisig::COLS[] = "trx_hash, signature";
  const char* const hive_transactions_multisig::COLS_ARRAY[] = {"trx_hash", "signature"};
  static_assert(hive_transactions_multisig::COLS_ARRAY_LEN == sizeof(hive_transactions_multisig::COLS_ARRAY) / sizeof(hive_transactions_multisig::COLS_ARRAY[0]), "incorrect size of hive_transactions_multisig::COLS_ARRAY");

  std::tuple<fc::ripemd160, fc::ecc::compact_signature> to_tuple(const PSQL::processing_objects::process_transaction_multisig_t& transaction_multisig)
  {
    return std::make_tuple(transaction_multisig.hash, transaction_multisig.signature);
  }

  template<> const char hive_operations< container_view< std::vector<PSQL::processing_objects::process_operation_t> > >::TABLE[] = "hive.operations";
  template<> const char hive_operations< container_view< std::vector<PSQL::processing_objects::process_operation_t> > >::COLS[] = "id, block_num, trx_in_block, op_pos, op_type_id, timestamp, body_binary";
  template<> const char* const hive_operations<container_view<std::vector<PSQL::processing_objects::process_operation_t>>>::COLS_ARRAY[] = {"id", "block_num", "trx_in_block", "op_pos", "op_type_id", "timestamp", "body_binary"};
  static_assert(hive_operations<container_view<std::vector<PSQL::processing_objects::process_operation_t>>>::COLS_ARRAY_LEN == sizeof(hive_operations<container_view<std::vector<PSQL::processing_objects::process_operation_t>>>::COLS_ARRAY) / sizeof(hive_operations<container_view<std::vector<PSQL::processing_objects::process_operation_t>>>::COLS_ARRAY[0]), "incorrect size of hive_operation::COLS_ARRAY");

  template<> const char  hive_operations< std::vector<PSQL::processing_objects::process_operation_t> >::TABLE[] = "hive.operations";
  template<> const char  hive_operations< std::vector<PSQL::processing_objects::process_operation_t> >::COLS[] = "id, block_num, trx_in_block, op_pos, op_type_id, timestamp, body_binary";
  template<> const char* const hive_operations<std::vector<PSQL::processing_objects::process_operation_t>>::COLS_ARRAY[] = {"id", "block_num", "trx_in_block", "op_pos", "op_type_id", "timestamp", "body_binary"};
  static_assert(hive_operations<std::vector<PSQL::processing_objects::process_operation_t>>::COLS_ARRAY_LEN == sizeof(hive_operations<std::vector<PSQL::processing_objects::process_operation_t>>::COLS_ARRAY) / sizeof(hive_operations<std::vector<PSQL::processing_objects::process_operation_t>>::COLS_ARRAY[0]), "incorrect size of hive_operation::COLS_ARRAY");

  std::tuple<int64_t, int, int32_t, int32_t, int64_t, fc::time_point_sec, pqxx::binarystring> to_tuple(const PSQL::processing_objects::process_operation_t& operation)
  {
    std::vector<char> seserialized_op = fc::raw::pack_to_vector(operation.op);

    return std::make_tuple(operation.operation_id,
                           operation.block_number,
                           operation.trx_in_block,
                           operation.op_in_trx,
                           operation.op.which(),
                           operation.timestamp,
                           pqxx::binarystring(seserialized_op.data(), seserialized_op.size()));
  }



  template<> const char hive_accounts<std::vector<PSQL::processing_objects::account_data_t>>::TABLE[] = "hive.accounts";
  template<> const char hive_accounts<std::vector<PSQL::processing_objects::account_data_t>>::COLS[] = "id, name, block_num";
  template<> const char* const hive_accounts<std::vector<PSQL::processing_objects::account_data_t>>::COLS_ARRAY[] = {"id", "name", "block_num"};
  static_assert(hive_accounts<std::vector<PSQL::processing_objects::account_data_t>>::COLS_ARRAY_LEN == sizeof(hive_accounts<std::vector<PSQL::processing_objects::account_data_t>>::COLS_ARRAY) / sizeof(hive_accounts<std::vector<PSQL::processing_objects::account_data_t>>::COLS_ARRAY[0]), "incorrect size of hive_accounts::COLS_ARRAY");

  template<> const char hive_accounts< container_view< std::vector<PSQL::processing_objects::account_data_t> > >::TABLE[] = "hive.accounts";
  template<> const char hive_accounts< container_view< std::vector<PSQL::processing_objects::account_data_t> > >::COLS[] = "id, name, block_num";
  template<> const char* const hive_accounts< container_view< std::vector<PSQL::processing_objects::account_data_t> > >::COLS_ARRAY[] = {"id", "name", "block_num"};
  static_assert(hive_accounts<container_view<std::vector<PSQL::processing_objects::account_data_t>>>::COLS_ARRAY_LEN == sizeof(hive_accounts<container_view<std::vector<PSQL::processing_objects::account_data_t>>>::COLS_ARRAY) / sizeof(hive_accounts<container_view<std::vector<PSQL::processing_objects::account_data_t>>>::COLS_ARRAY[0]), "incorrect size of hive_accounts::COLS_ARRAY");

  std::tuple<int32_t, std::string, int> to_tuple(const PSQL::processing_objects::account_data_t& account)
  {
    return std::make_tuple(account.id, account.name, account.block_number);
  }

  template<> const char hive_account_operations< std::vector<PSQL::processing_objects::account_operation_data_t> >::TABLE[] = "hive.account_operations";
  template<> const char hive_account_operations< std::vector<PSQL::processing_objects::account_operation_data_t> >::COLS[] = "block_num, account_id, account_op_seq_no, operation_id, op_type_id";
  template<> const char* const hive_account_operations<std::vector<PSQL::processing_objects::account_operation_data_t>>::COLS_ARRAY[] = {"block_num", "account_id", "account_op_seq_no", "operation_id", "op_type_id"};
  static_assert(hive_account_operations<std::vector<PSQL::processing_objects::account_operation_data_t>>::COLS_ARRAY_LEN == sizeof(hive_account_operations<std::vector<PSQL::processing_objects::account_operation_data_t>>::COLS_ARRAY) / sizeof(hive_account_operations<std::vector<PSQL::processing_objects::account_operation_data_t>>::COLS_ARRAY[0]), "incorrect size of hive_account_operations::COLS_ARRAY");

  template<> const char hive_account_operations< container_view< std::vector<PSQL::processing_objects::account_operation_data_t> > >::TABLE[] = "hive.account_operations";
  template<> const char hive_account_operations< container_view< std::vector<PSQL::processing_objects::account_operation_data_t> > >::COLS[] = "block_num, account_id, account_op_seq_no, operation_id, op_type_id";
  template<> const char* const hive_account_operations<container_view<std::vector<PSQL::processing_objects::account_operation_data_t>>>::COLS_ARRAY[] = {"block_num", "account_id", "account_op_seq_no", "operation_id", "op_type_id"};
  static_assert(hive_account_operations<container_view<std::vector<PSQL::processing_objects::account_operation_data_t>>>::COLS_ARRAY_LEN == sizeof(hive_account_operations<container_view<std::vector<PSQL::processing_objects::account_operation_data_t>>>::COLS_ARRAY) / sizeof(hive_account_operations<container_view<std::vector<PSQL::processing_objects::account_operation_data_t>>>::COLS_ARRAY[0]), "incorrect size of hive_account_operations::COLS_ARRAY");

  std::tuple<int, int32_t, int32_t, int64_t, int32_t> to_tuple(const PSQL::processing_objects::account_operation_data_t& account_operation)
  {
    return std::make_tuple(account_operation.block_number, account_operation.account_id, account_operation.operation_seq_no,
                           account_operation.operation_id, account_operation.op_type_id);
  }


  const char hive_applied_hardforks::TABLE[] = "hive.applied_hardforks";
  const char hive_applied_hardforks::COLS[] = "hardfork_num, block_num, hardfork_vop_id";
  const char* const hive_applied_hardforks::COLS_ARRAY[] = {"hardfork_num", "block_num", "hardfork_vop_id"};
  static_assert(hive_applied_hardforks::COLS_ARRAY_LEN == sizeof(hive_applied_hardforks::COLS_ARRAY) / sizeof(hive_applied_hardforks::COLS_ARRAY[0]), "incorrect size of hive_applied_hardforks::COLS_ARRAY");
  std::tuple<int32_t, int, int64_t> to_tuple(const PSQL::processing_objects::applied_hardforks_t& applied_hardfork)
  {
    return std::make_tuple(applied_hardfork.hardfork_num, applied_hardfork.block_number, applied_hardfork.hardfork_vop_id);
  }

}}} // namespace hive::plugins::sql_serializer


