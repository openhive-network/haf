#include <hive/plugins/sql_serializer/accounts_collector.h>

#include <hive/chain/util/impacted.hpp>

namespace hive{ namespace plugins{ namespace sql_serializer {

  void filter_mgr::op_start( uint32_t trx_in_block )
  {
    _is_operation_accepted  = false;
    _current_trx_in_block   = trx_in_block;
  }

  void filter_mgr::remember()
  {
    _is_operation_accepted  = true;
    _is_block_accepted      = true;

    //Remember number of transaction that will be included into a database.
    if( _current_trx_in_block != -1 )
      _trx_in_block_filter_accepted.insert( _current_trx_in_block );
  }

  void filter_mgr::clear()
  {
    _is_operation_accepted = false;
    _is_block_accepted     = false;
    _current_trx_in_block  = 0;
    _trx_in_block_filter_accepted.clear();
  }

  bool filter_mgr::is_op_accepted()
  {
    return _is_operation_accepted;
  }

  bool filter_mgr::is_trx_accepted( uint32_t trx_in_block )
  {
    return _trx_in_block_filter_accepted.find( trx_in_block ) != _trx_in_block_filter_accepted.end();
  }

  bool filter_mgr::is_block_accepted()
  {
    return _is_block_accepted;
  }

  void accounts_collector::collect(int64_t operation_id, const hive::protocol::operation& op, uint32_t block_num, uint32_t trx_in_block)
  {
    _filter_mgr.op_start( trx_in_block );

    _processed_operation_id = operation_id;
    _block_num = block_num;
    _impacted.clear();
    hive::app::operation_get_impacted_accounts(op, _impacted);

    op.visit(*this);
  }

  void accounts_collector::operator()(const hive::protocol::account_create_operation& op)
  {
    fc::optional<hive::protocol::account_name_type> impacted_account = op.creator;
    process_account_creation_op(impacted_account);
  }

  void accounts_collector::operator()(const hive::protocol::account_create_with_delegation_operation& op)
  {
    fc::optional<hive::protocol::account_name_type> impacted_account = op.creator;
    process_account_creation_op(impacted_account);
  }

  void accounts_collector::operator()(const hive::protocol::create_claimed_account_operation& op)
  {
    fc::optional<hive::protocol::account_name_type> impacted_account = op.creator;
    process_account_creation_op(impacted_account);
  }

  void accounts_collector::operator()(const hive::protocol::pow_operation& op)
  {
    fc::optional<hive::protocol::account_name_type> impacted_account;

    // check if pow_operation is creating new account
    if( _chain_db.find_account(op.get_worker_account()) != nullptr )
      impacted_account = op.get_worker_account();

    process_account_creation_op(impacted_account);
  }

  void accounts_collector::operator()(const hive::protocol::pow2_operation& op)
  {
    fc::optional<hive::protocol::account_name_type> impacted_account;

    // check if pow_operation is creating new account
    hive::protocol::account_name_type worker_account;
    if( op.work.which() == hive::protocol::pow2_work::tag<hive::protocol::pow2>::value )
      worker_account = op.work.get<hive::protocol::pow2>().input.worker_account;
    else if( op.work.which() == hive::protocol::pow2_work::tag<hive::protocol::equihash_pow>::value )
      worker_account = op.work.get<hive::protocol::equihash_pow>().input.worker_account;

    if( _chain_db.find_account(worker_account) != nullptr )
      impacted_account = worker_account;

    process_account_creation_op(impacted_account);
  }

  void accounts_collector::operator()(const hive::protocol::account_created_operation& op)
  {
    on_new_account(op.new_account_name);
    if( _creation_operation_id.valid() )
      on_new_operation(op.new_account_name, *_creation_operation_id);
    on_new_operation(op.new_account_name, _processed_operation_id);

    if( op.creator != hive::protocol::account_name_type() )
      on_new_operation(op.creator, _processed_operation_id);
  }

  void accounts_collector::process_account_creation_op(fc::optional<hive::protocol::account_name_type> impacted_account)
  {
    _creation_operation_id = _processed_operation_id;

    if( impacted_account.valid() )
      on_new_operation(*impacted_account, _processed_operation_id);
  }

  void accounts_collector::on_new_account(const hive::protocol::account_name_type& account_name)
  {
    if( !_filter.is_tracked_account( account_name ) )
      return;

    _filter_mgr.remember();

    const hive::chain::account_object* account_ptr = _chain_db.find_account(account_name);
    FC_ASSERT(account_ptr!=nullptr, "account with name ${name} does not exist in chain database", ("name", account_name));
    account_ops_seq_object::id_type account_id(account_ptr->get_id());

    _chain_db.create< account_ops_seq_object >( *account_ptr );
    _cached_data.accounts.emplace_back(account_id, std::string(account_name), _block_num);
  }

  void accounts_collector::on_new_operation(const hive::protocol::account_name_type& account_name, int64_t operation_id)
  {
    if( !_filter.is_tracked_account( account_name ) )
      return;

    _filter_mgr.remember();

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

  void accounts_collector::clear()
  {
    _filter_mgr.clear();
  }

  bool accounts_collector::is_op_accepted()
  {
    return _filter_mgr.is_op_accepted();
  }

  bool accounts_collector::is_trx_accepted( uint32_t trx_in_block )
  {
    return _filter_mgr.is_trx_accepted( trx_in_block );
  }

  bool accounts_collector::is_block_accepted()
  {
    return _filter_mgr.is_block_accepted();
  }

}}} // namespace hive::plugins::sql_serializer
