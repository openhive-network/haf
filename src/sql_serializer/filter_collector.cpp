#include <hive/plugins/sql_serializer/filter_collector.hpp>

namespace hive{ namespace plugins{ namespace sql_serializer {

  filter_collector::filter_collector( const blockchain_data_filter& filter ): _filter( filter )
  {
  }

  bool filter_collector::is_op_accepted() const
  {
    return !_filter.is_enabled() || ( !_accounts_accepted.empty() && _operation_accepted );
  }

  bool filter_collector::is_account_tracked( const hive::protocol::account_name_type& account ) const
  {
    return !_filter.is_enabled() || ( _accounts_accepted.find( account ) != _accounts_accepted.end() );
  }

  void filter_collector::grab_tracked_account(const hive::protocol::account_name_type& account_name)
  {
    if( _filter.is_enabled() && _filter.is_tracked_account( account_name ) )
      _accounts_accepted.insert( account_name );
  }

  bool filter_collector::is_operation_tracked() const
  {
    return !_filter.is_enabled() || _operation_accepted;
  }

  void filter_collector::grab_tracked_operation( const hive::protocol::operation& op )
  {
    if( _filter.is_enabled() && _filter.is_tracked_operation( op ) )
      _operation_accepted = true;
  }

  void filter_collector::clear()
  {
    if( _filter.is_enabled() )
    {
      _operation_accepted = false;
      _accounts_accepted.clear();
    }
  }

}}} // namespace hive::plugins::sql_serializer
