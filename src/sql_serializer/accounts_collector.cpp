#include <hive/plugins/sql_serializer/accounts_collector.h>

#include <hive/chain/util/impacted.hpp>

namespace hive{ namespace plugins{ namespace sql_serializer {

  void accounts_collector::collect(int64_t operation_id, const hive::protocol::operation& op, uint32_t block_num)
  {
    _processed_operation_id = operation_id;
    
    FC_ASSERT(op.which() >= 0, "Negative value of operation type-id: ${t}", ("t", op.which()));
    FC_ASSERT(op.which() < std::numeric_limits<short>::max(), "Too big value of operation type-id: ${t}", ("t", op.which()));

    _processed_operation_type_id = static_cast<int32_t>(op.which());
    _block_num = block_num;
    _impacted.clear();
    hive::app::operation_get_impacted_accounts(op, _impacted);

    on_collect( op, _impacted );

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
      on_new_operation(op.new_account_name, *_creation_operation_id, _creation_operation_type_id);
    on_new_operation(op.new_account_name, _processed_operation_id, _processed_operation_type_id);

    if( op.creator != op.new_account_name )
      on_new_operation(op.creator, _processed_operation_id, _processed_operation_type_id);
  }

  void accounts_collector::process_account_creation_op(fc::optional<hive::protocol::account_name_type> impacted_account)
  {
    _creation_operation_id = _processed_operation_id;
    _creation_operation_type_id = _processed_operation_type_id;

    if( impacted_account.valid() )
      on_new_operation(*impacted_account, _processed_operation_id, _processed_operation_type_id);
  }

  void accounts_collector::on_new_account(const hive::protocol::account_name_type& account_name)
  {
    if( !on_before_new_account( account_name ) )
      return;

    const hive::chain::account_object* account_ptr = _chain_db.find_account(account_name);
    FC_ASSERT(account_ptr!=nullptr, "account with name ${name} does not exist in chain database", ("name", account_name));
    account_ops_seq_object::id_type account_id(account_ptr->get_id());

    _chain_db.create< account_ops_seq_object >( *account_ptr );
    _cached_data.accounts.emplace_back(account_id, std::string(account_name), _block_num);
  }

  void accounts_collector::on_new_operation(const hive::protocol::account_name_type& account_name, int64_t operation_id, int32_t operation_type_id)
  {
    bool _allow_add_operation = on_before_new_operation( account_name );

    const hive::chain::account_object* account_ptr = _chain_db.find_account(account_name);

    if( account_ptr == nullptr )
      return;

    account_ops_seq_object::id_type account_id(account_ptr->get_id());

    const account_ops_seq_object* op_seq_obj = _chain_db.find< account_ops_seq_object, hive::chain::by_id >( account_id );

    if( op_seq_obj == nullptr )
      return;

    if( _allow_add_operation )
      _cached_data.account_operations.emplace_back(_block_num, operation_id, account_id, op_seq_obj->operation_count, operation_type_id);

    _chain_db.modify( *op_seq_obj, [&]( account_ops_seq_object& o)
    {
      o.operation_count++;
    } );
  }

  filtered_accounts_collector::filtered_accounts_collector( hive::chain::database& chain_db , cached_data_t& cached_data, const blockchain_data_filter& filter )
                              :accounts_collector( chain_db, cached_data ), _filter_collector( filter )
  {
  }

  void filtered_accounts_collector::on_collect( const hive::protocol::operation& op, const flat_set<hive::protocol::account_name_type>& impacted )
  {
    _filter_collector.collect_tracked_operation( op );

    for( auto& name : impacted )
      _filter_collector.collect_tracked_account( name );
  }

  bool filtered_accounts_collector::on_before_new_account( const hive::protocol::account_name_type& account_name )
  {
    return _filter_collector.is_account_tracked( account_name );
  }

  bool filtered_accounts_collector::on_before_new_operation( const hive::protocol::account_name_type& account_name )
  {
    return _filter_collector.is_account_tracked( account_name ) && _filter_collector.is_operation_tracked();
  }
  
  bool filtered_accounts_collector::is_op_accepted() const
  {
    return _filter_collector.is_op_accepted();
  }

}}} // namespace hive::plugins::sql_serializer
