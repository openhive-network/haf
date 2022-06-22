#include <hive/plugins/sql_serializer/filter_collector.hpp>

namespace hive{ namespace plugins{ namespace sql_serializer {

  filter_collector::filter_collector( const blockchain_data_filter& filter ): _filter( filter )
  {
  }

  bool filter_collector::is_op_accepted() const
  {
    return !_filter.is_enabled() || ( !_accounts_accepted.empty() && _operation_accepted.current );
  }

  bool filter_collector::is_account_tracked( const hive::protocol::account_name_type& account ) const
  {
    return !_filter.is_enabled() || ( _accounts_accepted.find( account ) != _accounts_accepted.end() );
  }

  void filter_collector::collect_tracked_account( const hive::protocol::account_name_type& account_name )
  {
    if( _filter.is_enabled() && _filter.is_tracked_account( account_name ) )
      _accounts_accepted.insert( account_name );
  }

  bool filter_collector::is_operation_tracked( bool is_current_operation ) const
  {
    return !_filter.is_enabled() || ( is_current_operation ? _operation_accepted.current : _operation_accepted.previous );
  }

  void filter_collector::collect_tracked_operation( const hive::protocol::operation& op )
  {
    if( _filter.is_enabled() )
    {
      _accounts_accepted.clear();

      _operation_accepted.previous  = _operation_accepted.current;
      _operation_accepted.current   = _filter.is_tracked_operation( op );
    }
  }

}}} // namespace hive::plugins::sql_serializer
