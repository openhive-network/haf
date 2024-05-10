#pragma once

#include <hive/plugins/sql_serializer/sql_serializer_objects.hpp>
#include <hive/plugins/sql_serializer/data_container_view.h>
#include <hive/plugins/sql_serializer/data_2_sql_tuple_base.h>
#include <pqxx/pqxx>

#include <fc/io/json.hpp>

namespace hive::plugins::sql_serializer {

  struct hive_blocks
    {
    using container_t = std::vector<PSQL::processing_objects::process_block_t>;

    static const char TABLE[];
    static const char COLS[];

    struct data2sql_tuple : public data2_sql_tuple_base
      {
      using data2_sql_tuple_base::data2_sql_tuple_base;

      std::string operator()(typename container_t::const_reference data) const
      {
        return std::to_string(data.block_number) + "," + escape_raw(data.hash) + "," +
        escape_raw(data.prev_hash) + ", '" + data.created_at.to_iso_string() + "' ," + std::to_string(data.producer_account_id) + "," +
        escape_raw(data.transaction_merkle_root) + "," + escape(data.extensions) + "," + escape_raw(data.witness_signature) + ", '" + static_cast<std::string>(data.signing_key) + "'" + "," +
        std::to_string(data.hbd_interest_rate) + "," +
        to_string(data.total_vesting_fund_hive) + "," + to_string(data.total_vesting_shares) + "," +
        to_string(data.total_reward_fund_hive) + "," +
        to_string(data.virtual_supply) + "," + to_string(data.current_supply) + "," +
        to_string(data.current_hbd_supply) + "," + to_string(data.dhf_interval_ledger);
      }
      };
    };

  template< typename Container >
  struct hive_transactions
    {
    using container_t = Container;//container_view< std::vector<PSQL::processing_objects::process_transaction_t> >;

    static const char TABLE[];
    static const char COLS[];

    struct data2sql_tuple : public data2_sql_tuple_base
      {
      using data2_sql_tuple_base::data2_sql_tuple_base;

      std::string operator()(typename container_t::const_reference data) const
      {
        return std::to_string(data.block_number) + "," + std::to_string(data.trx_in_block) + "," + escape_raw(data.hash) + "," +
        std::to_string(data.ref_block_num) + "," + std::to_string(data.ref_block_prefix) + ",'" + data.expiration.to_iso_string() + "'," + escape_raw(data.signature);
      }
      };
    };

  struct hive_transactions_multisig
    {
    using container_t = std::vector<PSQL::processing_objects::process_transaction_multisig_t>;

    static const char TABLE[];
    static const char COLS[];

    struct data2sql_tuple : public data2_sql_tuple_base
      {
      using data2_sql_tuple_base::data2_sql_tuple_base;

      std::string operator()(typename container_t::const_reference data) const
      {
        return escape_raw(data.hash) + "," + escape_raw(data.signature);
      }
      };
    };

  template< typename Container >
  struct hive_operations
    {
    using container_t =  Container;
      //container_view< std::vector<PSQL::processing_objects::process_operation_t> >;

    static const char TABLE[];
    static const char COLS[];

    struct data2sql_tuple : public data2_sql_tuple_base
      {
      using data2_sql_tuple_base::data2_sql_tuple_base;

      std::string operator()(typename container_t::const_reference data) const
      {
        std::vector<char> opDeserialized = fc::raw::pack_to_vector( data.op );

        return std::to_string(data.operation_id) + ',' + std::to_string(data.trx_in_block) + ',' +
        std::to_string(data.op_in_trx) + ",'" + data.timestamp.to_iso_string() + "'," + escape_raw(opDeserialized) + "::bytea";
      }
      };
    };

  template< typename Container >
  struct hive_accounts
    {
    using container_t = Container;
    //using container_t = std::vector<PSQL::processing_objects::account_data_t>;

    static const char TABLE[];
    static const char COLS[];

    struct data2sql_tuple : public data2_sql_tuple_base
      {
      using data2_sql_tuple_base::data2_sql_tuple_base;

      std::string operator()(typename container_t::const_reference data)
      {
        std::string block_num = ( data.block_number == 0 ) ? "NULL" : std::to_string( data.block_number );
        return std::to_string(data.id) + ',' + escape(data.name) + ',' + block_num;
      }
      };
    };

  template< typename Container >
  struct hive_account_operations
    {
    using container_t = Container;

    static const char TABLE[];
    static const char COLS[];

    struct data2sql_tuple : public data2_sql_tuple_base
      {
      using data2_sql_tuple_base::data2_sql_tuple_base;

      std::string operator()(typename container_t::const_reference data) const
      {
        return std::to_string(data.block_number) + ',' + std::to_string(data.account_id) + ',' + std::to_string(data.operation_seq_no) + ',' +
        std::to_string(data.operation_id) + ',' + std::to_string(data.op_type_id);
      }
      };
    };

  struct hive_applied_hardforks
    {
    using container_t = std::vector<PSQL::processing_objects::applied_hardforks_t>;

    static const char TABLE[];
    static const char COLS[];

    struct data2sql_tuple : public data2_sql_tuple_base
      {
      using data2_sql_tuple_base::data2_sql_tuple_base;

      std::string operator()(typename container_t::const_reference data) const
      {
        return std::to_string(data.hardfork_num) + ',' + std::to_string(data.block_number) + ',' + std::to_string(data.hardfork_vop_id);
      }
      };
    };

  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::process_block_t& block);
  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::process_transaction_t& transaction);
  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::process_transaction_multisig_t& transaction_multisig);
  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::process_operation_t& operation);
  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::account_data_t& account);
  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::account_operation_data_t& account_operation);
  void write_row_to_stream(pqxx::stream_to& stream, const PSQL::processing_objects::applied_hardforks_t& applied_hardfork);

} // namespace hive::plugins::sql_serializer
