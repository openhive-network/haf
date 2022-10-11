#pragma once

#include <hive/plugins/sql_serializer/tables_descriptions.h>

namespace hive::plugins::sql_serializer {
  struct cached_data_t
    {
    hive_blocks::container_t blocks;
    std::vector<PSQL::processing_objects::process_transaction_t> transactions;
    hive_transactions_multisig::container_t transactions_multisig;
    std::vector<PSQL::processing_objects::process_operation_t> operations;
    std::vector<PSQL::processing_objects::account_data_t> accounts;
    std::vector<PSQL::processing_objects::account_operation_data_t> account_operations;
    std::vector<PSQL::processing_objects::applied_hardforks_t> applied_hardforks;

    size_t total_size;

    explicit cached_data_t(const size_t reservation_size) : total_size{ 0ul }
    {
      blocks.reserve(reservation_size);
      transactions.reserve(reservation_size);
      transactions_multisig.reserve(reservation_size);
      operations.reserve(reservation_size);
      accounts.reserve(reservation_size);
      account_operations.reserve(reservation_size);
      applied_hardforks.reserve(reservation_size);
    }

    ~cached_data_t()
    {
      ilog(
        "blocks: ${b} trx: ${t} operations: ${o} total size: ${ts}...",
        ("b", blocks.size() )
        ("t", transactions.size() )
        ("o", operations.size() )
        ("a", accounts.size() )
        ("ao", account_operations.size() )
        ("ah", applied_hardforks.size())
        ("ts", total_size )
        );
    }

    };

  using cached_containter_t = std::unique_ptr<cached_data_t>;
} //namespace hive::plugins::sql_serializer