#pragma once

#include <hive/plugins/sql_serializer/sql_serializer_objects.hpp>
#include <hive/plugins/sql_serializer/blockchain_data_filter.hpp>
#include <hive/plugins/sql_serializer/cached_data.h>

#include <hive/chain/database.hpp>

#include <map>
#include <vector>

namespace hive::plugins::sql_serializer {

  class filter_collector
  {
    private:

      flat_set<hive::protocol::account_name_type> _accounts_accepted;
      const blockchain_data_filter& _filter;

    public:

      filter_collector( const blockchain_data_filter& filter );

      bool exists_any_tracked_account() const;
      bool is_account_tracked( const hive::protocol::account_name_type& account ) const;

      void grab_tracked_account(const hive::protocol::account_name_type& account_name);
      void clear();
  };

  struct accounts_collector
    {
    typedef void result_type;

    accounts_collector( hive::chain::database& chain_db , cached_data_t& cached_data, const blockchain_data_filter& filter )
      : _chain_db(chain_db), _cached_data(cached_data), _filter_collector(filter) {}

    void collect(int64_t operation_id, const hive::protocol::operation& op, uint32_t block_num);

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

    bool is_op_accepted() const
    {
      return _filter_collector.exists_any_tracked_account();
    }

    private:
      void prepare_account_creation_op(const hive::protocol::account_name_type& account);
      void process_account_creation_op(fc::optional<hive::protocol::account_name_type> impacted_account);

      void on_new_account(const hive::protocol::account_name_type& account_name);

      void on_new_operation(const hive::protocol::account_name_type& account_name, int64_t operation_id);

    private:
      hive::chain::database& _chain_db;
      cached_data_t& _cached_data;
      int64_t _processed_operation_id = -1;
      uint32_t _block_num = 0;

      fc::optional<int64_t> _creation_operation_id;
      flat_set<hive::protocol::account_name_type> _impacted;

      filter_collector              _filter_collector;
    };

} // namespace hive::plugins::sql_serializer
