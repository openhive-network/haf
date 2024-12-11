#include <hive/plugins/sql_serializer/container_data_writer.h>
#include <hive/plugins/sql_serializer/indexes_controler.h>
#include <hive/plugins/sql_serializer/queries_commit_data_processor.h>

#include <appbase/application.hpp>

#include <fc/io/sstream.hpp>
#include <fc/log/logger.hpp>
#include <fc/thread/thread.hpp>

#include <mutex>
#include <set>
#include <map>

namespace hive { namespace plugins { namespace sql_serializer {

indexes_controler::indexes_controler( std::string db_url, uint32_t psql_index_threshold, appbase::application& app )
: _db_url( std::move(db_url) )
, _psql_index_threshold( psql_index_threshold )
, theApp( app ) {

}

bool
indexes_controler::are_indexes_dropped() const {
    bool are_indexes_dropped = false;
    queries_commit_data_processor dropped_indexes_checker(
               _db_url
            , "Check if indexes are dropped"
            , "consist"
            , [&are_indexes_dropped](const data_processor::data_chunk_ptr&, transaction_controllers::transaction& tx) -> data_processor::data_processing_status {

                pqxx::result data = tx.exec("select hive.are_indexes_dropped() as _result;");
                FC_ASSERT( !data.empty(), "No response from database" );
                FC_ASSERT( data.size() == 1, "Wrong data size" );
                const auto& record = data[0];
                are_indexes_dropped = record[ "_result" ].as<bool>();
                return data_processor::data_processing_status();
            }
            , nullptr
            , theApp
    );

    dropped_indexes_checker.trigger(data_processor::data_chunk_ptr(), 0);
    dropped_indexes_checker.join();

    return are_indexes_dropped;
}

void
indexes_controler::disable_indexes_depends_on_blocks( uint32_t number_of_blocks_to_insert ) {
  if (theApp.is_interrupt_request())
    return;

  bool dropping_indexes = number_of_blocks_to_insert > _psql_index_threshold;
  if (!dropping_indexes)
  {
    ilog( "Number of blocks to add is less than threshold for disabling indexes. Indexes won't be dropped. ${n}<${t}",("n", number_of_blocks_to_insert )("t", _psql_index_threshold ) );
    return;
  }

  ilog( "Number of blocks to sync is greater than threshold for disabling indexes. Indexes will be dropped. ${n}<${t}",("n", number_of_blocks_to_insert )("t", _psql_index_threshold ) );
  auto processor = start_commit_sql(false, "hive.disable_indexes_of_irreversible()", "disable indexes" );
  processor->join();
  ilog( "All irreversible blocks tables indexes are dropped" );
}

void
indexes_controler::enable_indexes() {
  if (theApp.is_interrupt_request())
    return;

  if ( !are_indexes_dropped() ) {
      ilog( "Indexes already created" );
      return;
  }

  ilog( "Restoring HAF indexes..." );
  fc::time_point restore_indexes_start_time = fc::time_point::now();

  auto restore_blocks_idxs = start_commit_sql( true, "hive.restore_indexes( 'hafd.blocks' )", "enable indexes" );
  auto restore_irreversible_idxs = start_commit_sql( true, "hive.restore_indexes( 'hafd.irreversible_data' )", "enable indexes" );
  auto restore_transactions_idxs = start_commit_sql( true, "hive.restore_indexes( 'hafd.transactions' )", "enable indexes" );
  auto restore_transactions_sigs_idxs = start_commit_sql( true, "hive.restore_indexes( 'hafd.transactions_multisig' )", "enable indexes" );
  auto restore_operations_idxs = start_commit_sql( true, "hive.restore_indexes( 'hafd.operations' )", "enable indexes" );
  auto restore_accounts_idxs = start_commit_sql( true, "hive.restore_indexes( 'hafd.accounts' )", "enable indexes" );
  auto restore_account_operations_idxs = start_commit_sql( true, "hive.restore_indexes( 'hafd.account_operations' )", "enable indexes" );
  auto restore_applied_hardforks_idxs = start_commit_sql( true, "hive.restore_indexes( 'hafd.applied_hardforks' )", "enable indexes" );

  join_processors(
    *restore_blocks_idxs,
    *restore_irreversible_idxs,
    *restore_transactions_idxs,
    *restore_transactions_sigs_idxs,
    *restore_operations_idxs,
    *restore_account_operations_idxs,
    *restore_accounts_idxs,
    *restore_applied_hardforks_idxs
  );

  fc::time_point cluster_start_time = fc::time_point::now();
  fc::microseconds restore_indexes_time = cluster_start_time - restore_indexes_start_time;
  ilog( "PROFILE: Restored HAF table indexes: ${t}s", ("t",restore_indexes_time.to_seconds()) );
}

void
indexes_controler::disable_constraints() {
  if (theApp.is_interrupt_request())
    return;

  auto processor = start_commit_sql(false, "hive.disable_fk_of_irreversible()", "disable fk-s" );
  processor->join();
  ilog( "All irreversible blocks tables foreign keys are dropped" );
}

void
indexes_controler::enable_constrains() {
  if (theApp.is_interrupt_request())
    return;

  ilog("Restoring HAF constraints...");
  fc::time_point restore_constraints_start_time = fc::time_point::now();

  auto restore_irreversible_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hafd.irreversible_data' )", "enable indexes" );
  auto restore_transactions_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hafd.transactions' )", "enable indexes" );
  auto restore_transactions_sigs_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hafd.transactions_multisig' )", "enable indexes" );
  auto restore_operations_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hafd.operations' )", "enable indexes" );
  auto restore_account_operations_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hafd.account_operations' )", "enable indexes" );
  auto restore_accounts_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hafd.accounts' )", "enable indexes" );
  auto restore_applied_hardforks_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hafd.applied_hardforks' )", "enable indexes" );

  join_processors(
    *restore_irreversible_fks,
    *restore_transactions_fks,
    *restore_transactions_sigs_fks,
    *restore_operations_fks,
    *restore_account_operations_fks,
    *restore_accounts_fks,
    *restore_applied_hardforks_fks
  );

  auto restore_blocks_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hafd.blocks' )", "enable indexes" );
  restore_blocks_fks->join();

  fc::microseconds restore_constraints_time = fc::time_point::now() - restore_constraints_start_time;
  ilog( "PROFILE: Restored HAF constraints: ${t}s", ("t",restore_constraints_time.to_seconds()) );
}

std::unique_ptr<queries_commit_data_processor>
indexes_controler::start_commit_sql( bool mode, const std::string& sql_function_call, std::string objects_name ) {
  ilog("${mode} ${objects_name}...", ("objects_name", objects_name )("mode", ( mode ? "Creating" : "Dropping" ) ) );

  std::string query = std::string("SELECT ") + sql_function_call + ";";
  std::string description = "Query processor: `" + query + "'";
  std::string short_description = "index_ctrl";
  auto processor=std::make_unique< queries_commit_data_processor >(_db_url, description, std::move(short_description), 
                                                                   [query, objects_name=std::move(objects_name), mode, description](const data_processor::data_chunk_ptr&, transaction_controllers::transaction& tx) -> data_processor::data_processing_status
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
    } , nullptr, theApp);

  processor->trigger(data_processor::data_chunk_ptr(), 0);
  return processor;
}

void indexes_controler::poll_and_create_indexes() {
  std::map<std::string, std::thread> active_threads; // Doesn't need mutex, because it's modified by one thread at a time
  std::set<std::string> threads_to_delete;
  std::mutex mtx; // Protects threads_to_delete

  while (!theApp.is_interrupt_request()) {
    ilog("Polling for tables with missing indexes...");

    // Check for requested table vacuums
    queries_commit_data_processor vacuum_requests_checker(
      _db_url,
      "Check for vacuum requests",
      "index_ctrl",
      [this](const data_processor::data_chunk_ptr&, transaction_controllers::transaction& tx) -> data_processor::data_processing_status {
        ilog("Checking for tables to vacuum...");
        pqxx::result data;
        try { data = tx.exec("SELECT table_name FROM hafd.vacuum_requests WHERE status = 'requested';"); } 
        catch (const pqxx::sql_error& e) 
        {
            elog("Error while checking for vacuum requests: ${e}", ("e", e.what()));
            return data_processor::data_processing_status();
        }
        ilog("Found ${count} tables with vacuum requests.", ("count", data.size()));

        // workaround, open separate connections for non-transactional start vacuum
        try 
        {
          auto vacuum_connection = std::make_unique<pqxx::connection>(_db_url);
          pqxx::nontransaction vacuum_txn(*vacuum_connection);
          for (const auto& record : data) {
            std::string table_name = record["table_name"].as<std::string>();
            std::string vacuum_command = "VACUUM FULL ANALYZE " + table_name;
            ilog("Performing vacuum: ${vacuum_command}", ("vacuum_command", vacuum_command));
            vacuum_txn.exec(vacuum_command);
            ilog("Vacuumed table: ${table_name}", ("table_name", table_name));
            tx.exec("UPDATE hafd.vacuum_requests SET status = 'vacuumed', last_vacuumed_time = NOW() WHERE table_name = '" + table_name + "';");
            ilog("Updated vacuum status for table: ${table_name}", ("table_name", table_name));
            }
        } 
        catch (const pqxx::sql_error& e) { elog("Error while vacuuming tables: ${e}", ("e", e.what())); }
        return data_processor::data_processing_status();
      },
      nullptr,
      theApp
    );

    vacuum_requests_checker.trigger(data_processor::data_chunk_ptr(), 0);
    vacuum_requests_checker.join();

    // Check for tables with missing indexes that are not currently being created
    queries_commit_data_processor missing_indexes_checker(
      _db_url,
      "Check for missing indexes",
      "index_ctrl",
      [this, &active_threads, &threads_to_delete, &mtx](const data_processor::data_chunk_ptr&, transaction_controllers::transaction& tx) -> data_processor::data_processing_status {
        dlog("Executing query to find tables with missing indexes...");
        pqxx::result data = tx.exec(
          "SELECT DISTINCT table_name "
          "FROM hafd.indexes_constraints "
          "WHERE status = 'missing' "
          "AND table_name NOT IN ("
          "  SELECT DISTINCT table_name "
          "  FROM hafd.indexes_constraints "
          "  WHERE status = 'creating'"
          ");"
        );
        dlog("Query executed. Found ${count} tables with missing indexes.", ("count", data.size()));

        for (const auto& record : data) {
          std::string table_name = record["table_name"].as<std::string>();
          dlog("Processing table: ${table_name}", ("table_name", table_name));
          // Check if a thread is already running for this table
          if (active_threads.find(table_name) != active_threads.end() && active_threads[table_name].joinable()) {
            ilog("A thread is already running for table: ${table_name}", ("table_name", table_name));
            continue;
          }

          ilog("NOTE: Starting a new thread to create indexes for table: ${table_name}", ("table_name", table_name));
          active_threads[table_name] = std::thread([this, table_name, &threads_to_delete, &mtx]() {
            auto processor = start_commit_sql(true, "hive.restore_indexes( '" + table_name + "', FALSE )", "restore indexes");
            processor->join();
            ilog("Finished creating indexes for table: ${table_name}", ("table_name", table_name));
            std::lock_guard g(mtx);
            threads_to_delete.insert(table_name); // Mark the thread for deletion
            ilog("Thread for table: ${table_name} has been marked for deletion", ("table_name", table_name));
          });
        }
        dlog("Finished processing tables with missing indexes.");
        return data_processor::data_processing_status();
      },
      nullptr,
      theApp
    );

    missing_indexes_checker.trigger(data_processor::data_chunk_ptr(), 0);
    missing_indexes_checker.join();
    dlog("Finished polling for tables with missing indexes, sleep for 10s.");
    // Sleep for 10 seconds before polling again
    fc::usleep(fc::seconds(10));

    // Delete threads marked for deletion
    {
      std::lock_guard g(mtx);
      for (const auto& table_name : threads_to_delete) {
        if (active_threads[table_name].joinable()) {
          ilog("Joining thread for table: ${table_name}", ("table_name", table_name));
          active_threads[table_name].join();
        }
        active_threads.erase(table_name);
      }
      threads_to_delete.clear();
    }
  }
  ilog("Interrupt request received, stopping polling for tables with missing indexes.");
  // Join all remaining threads before exiting
  for (auto& [table_name, thread] : active_threads) {
    if (thread.joinable()) {
      ilog("Joining thread for table: ${table_name}", ("table_name", table_name));
      thread.join();
    }
  }
}

}}} // namespace hive{ plugins { sql_serializer
