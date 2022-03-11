#include <hive/plugins/sql_serializer/blockchain_data_filter.hpp>

namespace hive{ namespace plugins{ namespace sql_serializer {

  bool blockchain_account_filter::is_trx_accepted( int64_t trx_in_block ) const
  {
    return trx_in_block_filter_accepted.find( trx_in_block ) != trx_in_block_filter_accepted.end();
  }

  bool blockchain_account_filter::is_tracked_account( const account_name_type& name ) const
  {
    return filter.is_tracked_account( name );
  }

  void blockchain_account_filter::remember_trx_id( int64_t trx_in_block )
  {
    //Remember number of transaction that will be included into a database.
    if( trx_in_block != -1 )
      trx_in_block_filter_accepted.insert( trx_in_block );
  }

  void blockchain_account_filter::fill( const boost::program_options::variables_map& options, const std::string& option_name )
  {
    filter.fill( options, option_name );
  }

  void blockchain_account_filter::clear()
  {
    trx_in_block_filter_accepted.clear();
  }

}}} // namespace hive::plugins::sql_serializer
