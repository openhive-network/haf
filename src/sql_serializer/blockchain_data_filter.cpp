#include <hive/plugins/sql_serializer/blockchain_data_filter.hpp>

namespace hive{ namespace plugins{ namespace sql_serializer {

  bool blockchain_filter::is_enabled() const
  {
    return enabled;
  }

  bool blockchain_filter::is_trx_accepted( int64_t trx_in_block ) const
  {
    return !is_enabled() || trx_in_block_filter_accepted.find( trx_in_block ) != trx_in_block_filter_accepted.end();
  }

  bool blockchain_filter::is_tracked_account( const account_name_type& name ) const
  {
    return !is_enabled() || accounts_filter_tracker->is_tracked_account( name );
  }

  bool blockchain_filter::is_tracked_operation( const operation& op ) const
  {
    return !is_enabled() || ( operations_filter_tracker->is_tracked_operation( op ) && operations_body_filter_tracker->is_tracked_operation( op ) );
  }

  void blockchain_filter::remember_trx_id( int64_t trx_in_block )
  {
    //Remember number of transaction that will be included into a database.
    if( is_enabled() && trx_in_block != -1 )
      trx_in_block_filter_accepted.insert( trx_in_block );
  }

  void blockchain_filter::fill( const boost::program_options::variables_map& options,
                                        const std::string& tracked_accounts,
                                        const std::string& tracked_operations,
                                        const std::string& tracked_body_operations )
  {
    if( is_enabled() )
    {
      ptr_account_tracker_base    _af   = ptr_account_tracker_base( new account_tracker<false>("acc-sql") );
      ptr_operation_tracker_base  _of   = ptr_operation_tracker_base( new operation_tracker<false, operation_filter>( "op-sql", op_helper ) );
      ptr_operation_tracker_base  _obf  = ptr_operation_tracker_base( new operation_tracker<false, operation_body_filter>( "opb-sql", op_helper ) );

      _af->fill( options, tracked_accounts );
      _of->fill( options, tracked_operations );
      _obf->fill( options, tracked_body_operations );

      if( _af->empty() && _of->empty() && _obf->empty() )
        enabled = false;

      accounts_filter_tracker         = _af->empty()   ? ptr_account_tracker_base( new account_tracker<true>() )                             : std::move( _af );
      operations_filter_tracker       = _of->empty()   ? ptr_operation_tracker_base( new operation_tracker<true, operation_filter>() )       : std::move( _of );
      operations_body_filter_tracker  = _obf->empty()  ? ptr_operation_tracker_base( new operation_tracker<true, operation_body_filter>() )  : std::move( _obf );
    }
  }

  void blockchain_filter::clear()
  {
    if( is_enabled() )
      trx_in_block_filter_accepted.clear();
  }

}}} // namespace hive::plugins::sql_serializer
