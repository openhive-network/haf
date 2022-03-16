#pragma once

#include <hive/plugins/sql_serializer/blockchain_data_filter.hpp>

namespace hive::plugins::sql_serializer {

  class filter_collector
  {
    private:

      bool _operation_accepted = false;
      flat_set<hive::protocol::account_name_type> _accounts_accepted;

      const blockchain_data_filter& _filter;

    public:

      filter_collector( const blockchain_data_filter& filter );

      bool is_op_accepted() const;

      bool is_account_tracked( const hive::protocol::account_name_type& account ) const;
      void collect_tracked_account( const hive::protocol::account_name_type& account_name );

      bool is_operation_tracked() const;
      void collect_tracked_operation( const hive::protocol::operation& op );

      void clear();
  };

} // namespace hive::plugins::sql_serializer
