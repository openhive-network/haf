#include <hive/plugins/sql_serializer/accounts_collector.h>

#include <hive/chain/util/impacted.hpp>

#define DIAGNOSTIC(s)
//#define DIAGNOSTIC(s) s

namespace hive{ namespace plugins{ namespace sql_serializer {

  filter_collector::filter_collector( const blockchain_data_filter& filter ): _filter( filter )
  {
  }

  bool filter_collector::exists_any_tracked_account() const
  {
    return !_accounts_accepted.empty();
  }

  bool filter_collector::is_account_tracked( const hive::protocol::account_name_type& account ) const
  {
    return _accounts_accepted.find( account ) != _accounts_accepted.end();
  }

  void filter_collector::grab_tracked_account(const hive::protocol::account_name_type& account_name)
  {
    if( _filter.is_tracked_account( account_name ) )
      _accounts_accepted.insert( account_name );
  }

  void filter_collector::clear()
  {
    _accounts_accepted.clear();
  }

  void accounts_collector::collect(int64_t operation_id, const hive::protocol::operation& op, uint32_t block_num)
  {
    _processed_operation_id = operation_id;
    _block_num = block_num;
    _filter_collector.clear();
    _impacted.clear();
    hive::app::operation_get_impacted_accounts(op, _impacted);

    op.visit(*this);
  }

  void accounts_collector::operator()(const hive::protocol::account_create_operation& op)
  {
    fc::optional<hive::protocol::account_name_type> impacted_account = op.creator;
    process_account_creation_op(impacted_account);
    _filter_collector.grab_tracked_account( op.new_account_name );
  }

  void accounts_collector::operator()(const hive::protocol::account_create_with_delegation_operation& op)
  {
    fc::optional<hive::protocol::account_name_type> impacted_account = op.creator;
    process_account_creation_op(impacted_account);
    _filter_collector.grab_tracked_account( op.new_account_name );
  }

  void accounts_collector::operator()(const hive::protocol::create_claimed_account_operation& op)
  {
    fc::optional<hive::protocol::account_name_type> impacted_account = op.creator;
    process_account_creation_op(impacted_account);
    _filter_collector.grab_tracked_account( op.new_account_name );
  }

  void accounts_collector::operator()(const hive::protocol::pow_operation& op)
  {
    // check if pow_operation is creating new account
    prepare_account_creation_op( op.get_worker_account() );
  }

  void accounts_collector::operator()(const hive::protocol::pow2_operation& op)
  {
    // check if pow_operation is creating new account
    hive::protocol::account_name_type worker_account;
    if( op.work.which() == hive::protocol::pow2_work::tag<hive::protocol::pow2>::value )
      worker_account = op.work.get<hive::protocol::pow2>().input.worker_account;
    else if( op.work.which() == hive::protocol::pow2_work::tag<hive::protocol::equihash_pow>::value )
      worker_account = op.work.get<hive::protocol::equihash_pow>().input.worker_account;

    prepare_account_creation_op( worker_account );
  }

  void accounts_collector::operator()(const hive::protocol::account_created_operation& op)
  {
    on_new_account(op.new_account_name);
    if( _creation_operation_id.valid() )
      on_new_operation(op.new_account_name, *_creation_operation_id);
    on_new_operation(op.new_account_name, _processed_operation_id);

    if( op.creator != hive::protocol::account_name_type() )
      on_new_operation(op.creator, _processed_operation_id);
    else
      _filter_collector.grab_tracked_account( op.creator );
  }

  void accounts_collector::prepare_account_creation_op( const hive::protocol::account_name_type& account)
  {
    fc::optional<hive::protocol::account_name_type> impacted_account;

    if( _chain_db.find_account(account) != nullptr )
      impacted_account = account;
    else
      _filter_collector.grab_tracked_account( account );

    process_account_creation_op(impacted_account);
  }

  void accounts_collector::process_account_creation_op(fc::optional<hive::protocol::account_name_type> impacted_account)
  {
    _creation_operation_id = _processed_operation_id;

    if( impacted_account.valid() )
      on_new_operation(*impacted_account, _processed_operation_id);
  }

  void accounts_collector::on_new_account(const hive::protocol::account_name_type& account_name)
  {
    _filter_collector.grab_tracked_account( account_name );
    if( !_filter_collector.is_account_tracked( account_name ) )
    {
      DIAGNOSTIC( ilog("no [${_block_num}] account: ${account_name}", ("_block_num", _block_num)("account_name", account_name) ); )
      return;
    }

    DIAGNOSTIC( ilog("[${_block_num}] account: ${account_name}", ("_block_num", _block_num)("account_name", account_name) ); )

    const hive::chain::account_object* account_ptr = _chain_db.find_account(account_name);
    FC_ASSERT(account_ptr!=nullptr, "account with name ${name} does not exist in chain database", ("name", account_name));
    account_ops_seq_object::id_type account_id(account_ptr->get_id());

    _chain_db.create< account_ops_seq_object >( *account_ptr );
    _cached_data.accounts.emplace_back(account_id, std::string(account_name), _block_num);
  }

  void accounts_collector::on_new_operation(const hive::protocol::account_name_type& account_name, int64_t operation_id)
  {
    _filter_collector.grab_tracked_account( account_name );
    if( !_filter_collector.is_account_tracked( account_name ) )
    {
      DIAGNOSTIC( ilog("no [${_block_num}] account: ${account_name} op_id: ${operation_id}", ("_block_num", _block_num)("account_name", account_name)("operation_id", operation_id) ); )
      return;
    }

    DIAGNOSTIC( ilog("[${_block_num}] account: ${account_name} op_id: ${operation_id}", ("_block_num", _block_num)("account_name", account_name)("operation_id", operation_id) ); )

    const hive::chain::account_object* account_ptr = _chain_db.find_account(account_name);
    FC_ASSERT(account_ptr!=nullptr, "account with name ${name} does not exist in chain database", ("name", account_name));
    account_ops_seq_object::id_type account_id(account_ptr->get_id());

    const account_ops_seq_object& op_seq_obj = _chain_db.get< account_ops_seq_object, hive::chain::by_id >( account_id );
    _cached_data.account_operations.emplace_back(_block_num, operation_id, account_id, op_seq_obj.operation_count);
    _chain_db.modify( op_seq_obj, [&]( account_ops_seq_object& o)
    {
      o.operation_count++;
    } );
  }

}}} // namespace hive::plugins::sql_serializer
