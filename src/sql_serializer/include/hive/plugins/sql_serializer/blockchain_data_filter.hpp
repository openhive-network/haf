#pragma once

#include <hive/utilities/data_filter.hpp>
#include<set>

namespace hive::plugins::sql_serializer {

  using hive::plugins::account_filter;
  using hive::protocol::account_name_type;

  struct blockchain_data_filter
  {
    virtual bool is_enabled() const = 0;
    virtual bool is_tracked_account( const account_name_type& name ) const = 0;
    virtual bool is_tracked_operation( const operation& op ) const = 0;
  };

  struct blockchain_account_filter: public blockchain_data_filter
  {
    private:

      bool              enabled = false;

      std::set<int64_t> trx_in_block_filter_accepted;
      account_filter    accounts_filter;
      operation_filter  operations_filter;

    public:

      blockchain_account_filter( bool _enabled ): enabled( _enabled ), accounts_filter("acc-sql"), operations_filter("op-sql") {}

      bool is_enabled() const override;
      bool is_trx_accepted( int64_t trx_in_block ) const;

      bool is_tracked_account( const account_name_type& name ) const override;
      bool is_tracked_operation( const operation& op ) const override;

      void remember_trx_id( int64_t trx_in_block );
      void fill( const boost::program_options::variables_map& options, const std::string& tracked_accounts, const std::string& tracked_operations );
      void clear();
  };

} // namespace hive::plugins::sql_serializer
