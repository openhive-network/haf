#include <hive/plugins/sql_serializer/blockchain_data_filter.hpp>

namespace hive{ namespace plugins{ namespace sql_serializer {

  bool blockchain_account_filter::is_enabled() const
  {
    return enabled;
  }

  bool blockchain_account_filter::is_trx_accepted( int64_t trx_in_block ) const
  {
    return !is_enabled() || trx_in_block_filter_accepted.find( trx_in_block ) != trx_in_block_filter_accepted.end();
  }

  bool blockchain_account_filter::is_tracked_account( const account_name_type& name ) const
  {
    return !is_enabled() || accounts_filter.is_tracked_account( name );
  }

  bool blockchain_account_filter::is_tracked_operation( const operation& op ) const
  {
    return !is_enabled() || operations_filter.is_tracked_operation( op );
  }

  void blockchain_account_filter::remember_trx_id( int64_t trx_in_block )
  {
    //Remember number of transaction that will be included into a database.
    if( is_enabled() && trx_in_block != -1 )
      trx_in_block_filter_accepted.insert( trx_in_block );
  }

  void blockchain_account_filter::fill( const boost::program_options::variables_map& options,
                                        const std::string& tracked_accounts,
                                        const std::string& tracked_operations,
                                        const std::string& tracked_body_operations )
  {
    if( is_enabled() )
    {
      accounts_filter.fill( options, tracked_accounts );
      operations_filter.fill( options, tracked_operations );
      operations_body_filter.fill( options, tracked_body_operations );

      if( accounts_filter.empty() && operations_filter.empty() && operations_body_filter.empty() )
        enabled = false;
    }
  }

  void blockchain_account_filter::clear()
  {
    if( is_enabled() )
      trx_in_block_filter_accepted.clear();
  }

}}} // namespace hive::plugins::sql_serializer
