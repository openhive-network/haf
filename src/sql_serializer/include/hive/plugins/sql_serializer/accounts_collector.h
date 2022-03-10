#pragma once

#include <hive/plugins/sql_serializer/sql_serializer_objects.hpp>
#include <hive/plugins/sql_serializer/cached_data.h>
#include <hive/utilities/data_filter.hpp>

#include <hive/chain/database.hpp>

#include <map>
#include <vector>

namespace hive::plugins::sql_serializer {

  class filter_mgr
  {
    private:

      bool                _is_operation_accepted = false;
      bool                _is_block_accepted     = false;
      int32_t             _current_trx_in_block  = 0;

      std::set<uint32_t>  _trx_in_block_filter_accepted;

    public:

      void op_start( uint32_t trx_in_block );
      void remember();

      void clear();
      bool is_op_accepted();
      bool is_trx_accepted( uint32_t trx_in_block );
      bool is_block_accepted();
  };

  using hive::plugins::data_filter;
  struct accounts_collector
    {
    typedef void result_type;

    accounts_collector( hive::chain::database& chain_db , cached_data_t& cached_data, data_filter& filter )
      : _chain_db(chain_db), _cached_data(cached_data), _filter(filter) {}

    void collect(int64_t operation_id, const hive::protocol::operation& op, uint32_t block_num, uint32_t trx_in_block);

    void operator()(const hive::protocol::account_create_operation& op);

    void operator()(const hive::protocol::account_create_with_delegation_operation& op);

    void operator()(const hive::protocol::create_claimed_account_operation& op);

    void operator()(const hive::protocol::pow_operation& op);

    void operator()(const hive::protocol::pow2_operation& op);

    void operator()(const hive::protocol::account_created_operation& op);

    template< typename T >
    void operator()(const T& op)
    {
      for( const auto& account_name : _impacted )
        on_new_operation(account_name, _processed_operation_id);
    }

    void clear();
    bool is_op_accepted();
    bool is_trx_accepted( uint32_t trx_in_block );
    bool is_block_accepted();

    private:
      void process_account_creation_op(fc::optional<hive::protocol::account_name_type> impacted_account);

      void on_new_account(const hive::protocol::account_name_type& account_name);

      void on_new_operation(const hive::protocol::account_name_type& account_name, int64_t operation_id);

    private:
      hive::chain::database& _chain_db;
      cached_data_t& _cached_data;
      data_filter& _filter;
      filter_mgr   _filter_mgr;
      int64_t _processed_operation_id = -1;
      uint32_t _block_num = 0;

      fc::optional<int64_t> _creation_operation_id;
      flat_set<hive::protocol::account_name_type> _impacted;
    };

} // namespace hive::plugins::sql_serializer