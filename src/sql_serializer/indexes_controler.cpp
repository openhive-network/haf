#include <hive/plugins/sql_serializer/container_data_writer.h>
#include <hive/plugins/sql_serializer/indexes_controler.h>
#include <hive/plugins/sql_serializer/queries_commit_data_processor.h>
#include <hive/plugins/sql_serializer/indexes_interruptor.h>

#include <appbase/application.hpp>

#include <fc/io/sstream.hpp>
#include <fc/log/logger.hpp>
#include <fc/thread/thread.hpp>

#include <mutex>
#include <set>
#include <map>
#include <regex>

namespace hive { namespace plugins { namespace sql_serializer {

namespace {
std::string db_url_with_app(const std::string& db_url, const char* app_name)
{
  const std::string app_kv = std::string("application_name=") + app_name;
  if (db_url.find("application_name=") != std::string::npos)
    return db_url;
  const bool is_uri = db_url.rfind("postgres://", 0) == 0 || db_url.rfind("postgresql://", 0) == 0;
  if (is_uri)
  {
    const char sep = (db_url.find('?') == std::string::npos) ? '?' : '&';
    return db_url + sep + app_kv;
  }
  return db_url + " " + app_kv;
}

std::string db_url_as_user(const std::string& db_url, const char* user)
{
  const std::string user_kv = std::string("user=") + user;
  const bool is_uri = db_url.rfind("postgres://", 0) == 0 || db_url.rfind("postgresql://", 0) == 0;
  if (is_uri)
  {
    // URI format: replace existing user or add to query params
    std::regex user_regex(R"(([?&])user=[^&]*)");
    if (std::regex_search(db_url, user_regex))
      return std::regex_replace(db_url, user_regex, std::string("$1") + user_kv);
    const char sep = (db_url.find('?') == std::string::npos) ? '?' : '&';
    return db_url + sep + user_kv;
  }
  else return db_url + " " + user_kv; // Key-value format: append
}

std::string db_url_with_hived_app(const std::string& db_url)
{
  return db_url_with_app(db_url, "hived_index");
}

std::string db_url_with_hived_app_as_haf_maintainer(const std::string& db_url)
{
  return db_url_with_hived_app(db_url_as_user(db_url, "haf_maintainer"));
}

}

indexes_controler::indexes_controler( std::string db_url, uint32_t psql_index_threshold, appbase::application& app )
: _db_url( std::move(db_url) )
, _psql_index_threshold( psql_index_threshold )
, _interruptor(_db_url, app)
, theApp( app )
{
}

bool
indexes_controler::are_any_indexes_missing() const {
    bool are_any_indexes_missing = false;
    queries_commit_data_processor dropped_indexes_checker(
               _db_url
            , "Check if indexes are dropped"
            , "consist"
            , [&are_any_indexes_missing](const data_processor::data_chunk_ptr&, transaction_controllers::transaction& tx) -> data_processor::data_processing_status {

                pqxx::result data = tx.exec("select hive.are_any_indexes_missing() as _result;");
                FC_ASSERT( !data.empty(), "No response from database" );
                FC_ASSERT( data.size() == 1, "Wrong data size" );
                const auto& record = data[0];
                are_any_indexes_missing = record[ "_result" ].as<bool>();
                return data_processor::data_processing_status();
            }
            , nullptr
            , theApp
    );

    dropped_indexes_checker.trigger(data_processor::data_chunk_ptr(), 0);
    dropped_indexes_checker.join();

    return are_any_indexes_missing;
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

  if ( !are_any_indexes_missing() ) {
      ilog( "Indexes already created" );
      return;
  }

  ilog( "Restoring HAF indexes..." );
  fc::time_point restore_indexes_start_time = fc::time_point::now();

  auto restore_blocks_idxs = start_commit_sql( true, "hive.restore_indexes( 'hafd.blocks' )", "blocks indexes" );
  auto restore_irreversible_idxs = start_commit_sql( true, "hive.restore_indexes( 'hafd.hive_state' )", "hive_state indexes" );
  auto restore_transactions_idxs = start_commit_sql( true, "hive.restore_indexes( 'hafd.transactions' )", "transactions indexes" );
  auto restore_transactions_sigs_idxs = start_commit_sql( true, "hive.restore_indexes( 'hafd.transactions_multisig' )", "transactions_multisig indexes" );
  auto restore_operations_idxs = start_commit_sql( true, "hive.restore_indexes( 'hafd.operations' )", "operations indexes" );
  auto restore_accounts_idxs = start_commit_sql( true, "hive.restore_indexes( 'hafd.accounts' )", "accounts indexes" );
  auto restore_account_operations_idxs = start_commit_sql( true, "hive.restore_indexes( 'hafd.account_operations' )", "account_operations indexes" );
  auto restore_applied_hardforks_idxs = start_commit_sql( true, "hive.restore_indexes( 'hafd.applied_hardforks' )", "applied_hardforks indexes" );

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

  auto restore_irreversible_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hafd.hive_state' )", "hive_state foreign keys" );
  auto restore_transactions_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hafd.transactions' )", "transactions foreign keys" );
  auto restore_transactions_sigs_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hafd.transactions_multisig' )", "transactions_multisig foreign keys" );
  auto restore_operations_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hafd.operations' )", "operations foreign keys" );
  auto restore_account_operations_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hafd.account_operations' )", "account_operations foreign keys" );
  auto restore_accounts_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hafd.accounts' )", "accounts foreign keys" );
  auto restore_applied_hardforks_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hafd.applied_hardforks' )", "applied_hardforks foreign keys" );

  join_processors(
    *restore_irreversible_fks,
    *restore_transactions_fks,
    *restore_transactions_sigs_fks,
    *restore_operations_fks,
    *restore_account_operations_fks,
    *restore_accounts_fks,
    *restore_applied_hardforks_fks
  );

  auto restore_blocks_fks = start_commit_sql( true, "hive.restore_foreign_keys( 'hafd.blocks' )", "blocks foreign keys" );
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
  auto processor=std::make_unique< queries_commit_data_processor >(db_url_with_hived_app(_db_url), description, std::move(short_description), 
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

void indexes_controler::poll_and_create_indexes() 
{
  std::map<std::string, std::thread> active_threads; // Doesn't need mutex, because it's modified by one thread at a time
  std::set<std::string> threads_to_delete;
  std::mutex mtx; // Protects threads_to_delete

  const std::string thread_name = "haf_monitor";
  fc::set_thread_name(thread_name.c_str());
  fc::thread::current().set_name(thread_name);


  {
    pqxx::connection conn(db_url_with_hived_app_as_haf_maintainer(_db_url));
    pqxx::nontransaction tx(conn);
    try
    {
      dlog("Resetting indexes creation states before polling loop...");
      tx.exec("UPDATE hafd.indexes_constraints SET status = 'missing' WHERE status = 'creating';");
    }
    catch (const std::exception& e)
    {
      elog("Error while resetting indexes creation states: ${e}", ("e", e.what()));
    }
  }

  while (!theApp.is_interrupt_request())
  {
    dlog("Checking for table vacuum requests...");
    pqxx::connection conn(db_url_with_hived_app_as_haf_maintainer(_db_url));
    pqxx::nontransaction tx(conn);
    try
    {
      pqxx::result data = tx.exec("SELECT schema_name, table_name FROM hafd.vacuum_requests WHERE status = 'requested';"); 
      dlog("Found ${count} tables with vacuum requests.", ("count", data.size()));

      for (const auto& record : data)
      {
        std::string schema_name;
        std::string table_name;
        try
        {
          schema_name = record["schema_name"].as<std::string>();
          table_name = record["table_name"].as<std::string>();
          std::string qualified_table_name = tx.quote_name(schema_name) + "." + tx.quote_name(table_name);
          std::string vacuum_command = "VACUUM FULL ANALYZE " + qualified_table_name;

          ilog("Performing vacuum: ${vacuum_command}", (vacuum_command));
          auto start_time = fc::time_point::now();
          tx.exec(vacuum_command);
          auto end_time = fc::time_point::now();
          fc::microseconds vacuum_duration = end_time - start_time;
          ilog("Vacuumed table: ${schema}.${table} in ${duration} seconds", ("schema", schema_name)("table", table_name)("duration", vacuum_duration.to_seconds()));

          tx.exec_params(
            "UPDATE hafd.vacuum_requests SET status = 'vacuumed', last_vacuumed_time = NOW(), error_message = NULL WHERE schema_name = $1 AND table_name = $2",
            schema_name,
            table_name
          );
          ilog("Updated vacuum status for table: ${schema}.${table}", ("schema", schema_name)("table", table_name));
        }
        catch (const std::exception& e)
        {
          elog("Error while vacuuming table: ${schema}.${table}: ${e}", ("schema", schema_name)("table", table_name)("e", e.what()));

          try
          {
            std::string error_msg = e.what();

            tx.exec_params(
              "UPDATE hafd.vacuum_requests SET status = 'failed', error_message = $1 WHERE schema_name = $2 AND table_name = $3",
              error_msg,
              schema_name,
              table_name
            );
          }
          catch (const std::exception& update_error)
          {
            elog("Error while updating vacuum failure status for table ${schema}.${table}: ${e}", ("schema", schema_name)("table", table_name)("e", update_error.what()));
          }
        }
      }
    }
    catch (const std::exception& e)
    {
      elog("Error while checking for vacuum requests: ${e}", ("e", e.what()));
    }

    // Check for tables with missing indexes that are not currently being created
    try 
    { 
      dlog("Executing query to find tables with missing indexes...");
      pqxx::result data = tx.exec(
            "SELECT DISTINCT table_name "
            "FROM hafd.indexes_constraints "
            "WHERE status = 'missing' "
            "AND table_name LIKE 'hafd.%' "
            "AND table_name NOT IN ("
            "  SELECT DISTINCT table_name "
            "  FROM hafd.indexes_constraints "
            "  WHERE status = 'creating'"
            ");"
        );
      dlog("Query executed. Found ${count} tables with missing indexes.", ("count", data.size()));
      for (const auto& record : data) //iterate over tables with missing indexes
      {
        std::string table_name = record["table_name"].as<std::string>();
        dlog("Processing table: ${table_name}", ("table_name", table_name));
        // Check if a thread is already running for this table
        if (active_threads.find(table_name) != active_threads.end() && active_threads[table_name].joinable()) 
        {
          ilog("A thread is already running for table: ${table_name}", ("table_name", table_name));
          continue; //check the next table
        }

        ilog("NOTE: Starting a new thread to create indexes for table: ${table_name}", ("table_name", table_name));
        active_threads[table_name] = std::thread([this, table_name, &threads_to_delete, &mtx]() 
        {
          std::string thread_name = table_name;
          if (thread_name.size() > 16)
            thread_name.resize(16);
          fc::set_thread_name(thread_name.c_str());
          fc::thread::current().set_name(thread_name);

          pqxx::connection conn(db_url_with_hived_app_as_haf_maintainer(_db_url));
          pqxx::nontransaction tx(conn);
          pqxx::result data = tx.exec("SELECT index_constraint_name, command FROM hafd.indexes_constraints WHERE status = 'missing' AND table_name = '" + table_name + "';");
          for (const auto& index : data) //iterate over missing indexes and create them concurrently
          {
            std::string index_constraint_name = index["index_constraint_name"].as<std::string>();
            try
            {
              std::string original_command = index["command"].as<std::string>();
              ilog("Processing index ${idx} for table ${tbl}: original_command=${cmd}",
                   ("idx", index_constraint_name)("tbl", table_name)("cmd", original_command));
              // Check if the target table is a hypertable (partitioned table).
              // CREATE INDEX CONCURRENTLY is not supported on TimescaleDB hypertables.
              bool is_hypertable = false;
              {
                // Extract schema.table from "CREATE INDEX ... ON schema.table ..."
                std::regex on_table_regex(R"(ON\s+(?:ONLY\s+)?(\w+)\.(\w+))", std::regex::icase);
                std::smatch on_match;
                if (std::regex_search(original_command, on_match, on_table_regex))
                {
                  std::string schema = on_match[1].str();
                  std::string tbl = on_match[2].str();
                  ilog("Checking if ${schema}.${tbl} is a hypertable (relkind='p')...", ("schema", schema)("tbl", tbl));
                  pqxx::result r = tx.exec(
                    "SELECT c.relkind FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace "
                    "WHERE n.nspname = '" + schema + "' AND c.relname = '" + tbl + "'");
                  if (!r.empty())
                  {
                    std::string relkind = r[0][0].as<std::string>();
                    ilog("${schema}.${tbl} relkind='${rk}'", ("schema", schema)("tbl", tbl)("rk", relkind));
                    is_hypertable = (relkind == "p");
                  }
                  else
                  {
                    elog("Table ${schema}.${tbl} not found in pg_class!", ("schema", schema)("tbl", tbl));
                  }
                }
                else
                {
                  elog("Could not parse table name from command: ${cmd}", ("cmd", original_command));
                }
              }
              // For regular tables, use CONCURRENTLY to avoid blocking writes.
              // For hypertables, CONCURRENTLY is not supported — use TimescaleDB's
              // transaction_per_chunk which creates per-chunk indexes allowing
              // concurrent writes on other chunks.
              std::string command;
              if (is_hypertable)
              {
                // Insert WITH (timescaledb.transaction_per_chunk) for hypertable indexes.
                // Per SQL syntax, WITH must come BEFORE WHERE in CREATE INDEX.
                std::string cmd = original_command;
                // Strip trailing semicolons/whitespace
                while (!cmd.empty() && (cmd.back() == ';' || cmd.back() == ' '))
                  cmd.pop_back();
                // Find WHERE clause (case-insensitive) to insert WITH before it
                std::regex where_regex(R"(\bWHERE\b)", std::regex::icase);
                std::smatch where_match;
                if (std::regex_search(cmd, where_match, where_regex))
                {
                  // Insert WITH clause before WHERE
                  command = cmd.substr(0, where_match.position())
                          + "WITH (timescaledb.transaction_per_chunk) "
                          + cmd.substr(where_match.position());
                }
                else
                {
                  // No WHERE clause, just append
                  command = cmd + " WITH (timescaledb.transaction_per_chunk)";
                }
                ilog("Using transaction_per_chunk for hypertable index: ${cmd}", ("cmd", command));
              }
              else
              {
                std::regex create_index_regex(R"((CREATE\s+UNIQUE\s+INDEX|CREATE\s+INDEX))", std::regex::icase);
                command = std::regex_replace(original_command, create_index_regex, "$& CONCURRENTLY");
              }
              tx.exec("UPDATE hafd.indexes_constraints SET status = 'creating' WHERE index_constraint_name ='" + index_constraint_name + "';");
              ilog("Creating index: ${command}", (command));
              auto start_time = fc::time_point::now();
              tx.exec(command);
              auto end_time = fc::time_point::now();
              fc::microseconds index_creation_duration = end_time - start_time;
              ilog("Finished creating index for table: ${table_name} in ${duration} seconds", (table_name)("duration", index_creation_duration.to_seconds()));
              tx.exec("UPDATE hafd.indexes_constraints SET status = 'created' WHERE index_constraint_name ='"+index_constraint_name+"';");
            }
            catch (const std::exception& e)
            {
               elog("Error while creating index ${idx}: ${e}", ("idx", index_constraint_name)("e", e.what()));
               // The existing nontransaction tx may be in bad state after error.
               // We need a fresh connection to reset the status and store the error.
               try {
                 pqxx::connection reset_conn(db_url_with_hived_app_as_haf_maintainer(_db_url));
                 pqxx::nontransaction reset_tx(reset_conn);
                 std::string error_msg = e.what();
                 // Escape single quotes for SQL
                 std::string escaped_error;
                 for (char c : error_msg)
                 {
                   if (c == '\'') escaped_error += "''";
                   else escaped_error += c;
                 }
                 reset_tx.exec("UPDATE hafd.indexes_constraints SET status = 'missing', last_error = '" + escaped_error + "' WHERE index_constraint_name ='" + index_constraint_name + "';");
                 ilog("Reset index ${idx} status back to 'missing' for retry, error stored", ("idx", index_constraint_name));
               } catch (const std::exception& reset_e) {
                 elog("Failed to reset index status: ${e}", ("e", reset_e.what()));
               }
            }
          }
          ilog("Finished creating all indexes for table: ${table_name}", (table_name));
          try
          {
            ilog("Analyzing table: ${table_name}", (table_name) );
            std::string analyze_table = "ANALYZE " + table_name + ";";
            tx.exec(analyze_table);
          }
          catch (const std::exception& e)
          {
             elog("Error while analyzing table: ${e}", ("e", e.what()));
          }

          std::lock_guard g(mtx);
          threads_to_delete.insert(table_name); // Mark the thread for deletion
          ilog("Thread for table: ${table_name} has been marked for deletion", (table_name));
        });
      } //end for tables with missing indexes
      dlog("Finished polling for tables with missing indexes, sleep for 10s.");
    }
    catch (const std::exception& e)
    {
      elog("Error while checking for missing indexes: ${e}", ("e", e.what()));
    }

    // Sleep for 10 seconds before polling again
    fc::usleep(fc::seconds(10));

    // Delete threads marked for deletion
    {
      std::lock_guard g(mtx);
      for (const auto& table_name : threads_to_delete) 
      {
        if (active_threads[table_name].joinable()) 
        {
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
  for (auto& [table_name, thread] : active_threads) 
  {
    if (thread.joinable()) 
    {
      ilog("Joining thread for table: ${table_name}", ("table_name", table_name));
      thread.join();
    }
  }
} //end poll_and_create_indexes

}}} // namespace hive{ plugins { sql_serializer
