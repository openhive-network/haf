#pragma once

#include <hive/utilities/data_filter.hpp>
#include<set>

namespace hive::plugins::sql_serializer {

  using hive::plugins::data_filter;
  using hive::protocol::account_name_type;

  struct blockchain_data_filter
  {
    virtual bool is_tracked_account( const account_name_type& name ) const = 0;
  };

  struct blockchain_account_filter: public blockchain_data_filter
  {
    private:

      std::set<int64_t>  trx_in_block_filter_accepted;
      data_filter         filter;

    public:

      blockchain_account_filter(): filter("sql"){}

      bool is_trx_accepted( int64_t trx_in_block ) const;
      bool is_tracked_account( const account_name_type& name ) const override;

      void remember_trx_id( int64_t trx_in_block );
      void fill( const boost::program_options::variables_map& options, const std::string& option_name );
      void clear();
  };

} // namespace hive::plugins::sql_serializer
