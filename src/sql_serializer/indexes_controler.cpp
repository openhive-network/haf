#include <hive/plugins/sql_serializer/indexes_controler.h>
#include <hive/plugins/sql_serializer/queries_commit_data_processor.h>

#include <appbase/application.hpp>

#include <fc/io/sstream.hpp>
#include <fc/log/logger.hpp>


namespace hive { namespace plugins { namespace sql_serializer {

indexes_controler::indexes_controler( std::string db_url, uint32_t psql_index_threshold )
: _db_url( std::move(db_url) )
, _psql_index_threshold( psql_index_threshold ) {

}

void
indexes_controler::disable_indexes_depends_on_blocks( uint32_t number_of_blocks_to_insert ) {
  if (appbase::app().is_interrupt_request())
    return;

  bool can_disable_indexes = number_of_blocks_to_insert > _psql_index_threshold;

  if ( !can_disable_indexes ) {
    ilog( "Number of blocks to add is less than threshold for disabling indexes. Indexes won't be disabled. ${n}<${t}",("n", number_of_blocks_to_insert )("t", _psql_index_threshold ) );
    return;
  }

  auto processor = start_commit_sql(false, "hive.disable_indexes_of_irreversible()", "disable indexes" );
  processor->join();
  ilog( "All irreversible blocks tables indexes are dropped" );
}

void
indexes_controler::enable_indexes() {
  if (appbase::app().is_interrupt_request())
    return;

  auto restore_blocks_idxs = start_commit_sql( true, "hive.restore_indexes( 'hive.blocks' )", "enable indexes" );
  auto restore_irreversible_idxs = start_commit_sql( true, "hive.restore_indexes( 'hive.irreversible_data' )", "enable indexes" );
  auto restore_transactions_idxs = start_commit_sql( true, "hive.restore_indexes( 'hive.transactions' )", "enable indexes" );
  auto restore_transactions_sigs_idxs = start_commit_sql( true, "hive.restore_indexes( 'hive.transactions_multisig' )", "enable indexes" );
  auto restore_operations_idxs = start_commit_sql( true, "hive.restore_indexes( 'hive.operations' )", "enable indexes" );
  auto restore_accounts_idxs = start_commit_sql( true, "hive.restore_indexes( 'hive.accounts' )", "enable indexes" );
  auto restore_account_operations_idxs = start_commit_sql( true, "hive.restore_indexes( 'hive.account_operations' )", "enable indexes" );
  restore_blocks_idxs->join();
  restore_irreversible_idxs->join();
  restore_transactions_idxs->join();
  restore_transactions_sigs_idxs->join();
  restore_operations_idxs->join();
  restore_account_operations_idxs->join();
  restore_accounts_idxs->join();

  ilog( "All irreversible blocks tables indexes are re-created" );
}

void
indexes_controler::disable_constraints() {
  if (appbase::app().is_interrupt_request())
    return;

  auto processor = start_commit_sql(false, "hive.disable_fk_of_irreversible()", "disable fk-s" );
  processor->join();
  ilog( "All irreversible blocks tables foreign keys are dropped" );
}

void
indexes_controler::enable_constrains() {
  if (appbase::app().is_interrupt_request())
    return;

  auto restore_blocks_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hive.blocks' )", "enable indexes" );
  auto restore_irreversible_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hive.irreversible_data' )", "enable indexes" );
  auto restore_transactions_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hive.transactions' )", "enable indexes" );
  auto restore_transactions_sigs_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hive.transactions_multisig' )", "enable indexes" );
  auto restore_operations_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hive.operations' )", "enable indexes" );
  auto restore_accounts_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hive.accounts' )", "enable indexes" );
  auto restore_account_operations_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hive.account_operations' )", "enable indexes" );
  restore_blocks_fks->join();
  restore_irreversible_fks->join();
  restore_transactions_fks->join();
  restore_transactions_sigs_fks->join();
  restore_operations_fks->join();
  restore_accounts_fks->join();
  restore_account_operations_fks->join();

  ilog( "All irreversible blocks tables foreign keys are re-created" );
}

std::unique_ptr<queries_commit_data_processor>
indexes_controler::start_commit_sql( bool mode, const std::string& sql_function_call, const std::string& objects_name ) {
  ilog("${mode} ${objects_name}...", ("objects_name", objects_name )("mode", ( mode ? "Creating" : "Dropping" ) ) );

  std::string query = std::string("SELECT ") + sql_function_call + ";";
  std::string description = "Query processor: `" + query + "'";
  auto processor=std::make_unique< queries_commit_data_processor >(_db_url, description, [query, &objects_name, mode, description](const data_processor::data_chunk_ptr&, transaction_controllers::transaction& tx) -> data_processor::data_processing_status
  {
    ilog("Attempting to execute query: `${query}`...", ("query", query ) );
    const auto start_time = fc::time_point::now();
    tx.exec( query );
    ilog(
      "${d} ${mode} of ${mod_type} done in ${time} ms",
      ("d", description)("mode", (mode ? "Creating" : "Saving and dropping")) ("mod_type", objects_name) ("time", (fc::time_point::now() - start_time).count() / 1000.0 )
      );
    ilog("The ${objects_name} have been ${mode}...", ("objects_name", objects_name )("mode", ( mode ? "created" : "dropped" ) ) );
    return data_processor::data_processing_status();
    } , nullptr);

  processor->trigger(data_processor::data_chunk_ptr(), 0);
  return processor;
}

}}} // namespace hive{ plugins { sql_serializer
