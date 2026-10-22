#include <cstdint>
#include <hive/plugins/sql_serializer/container_data_writer.h>
#include <hive/plugins/sql_serializer/indexes_controler.h>
#include <hive/plugins/sql_serializer/queries_commit_data_processor.h>
#include <hive/plugins/sql_serializer/indexes_interruptor.h>
#include <hive/plugins/sql_serializer/vacuum_cleaner.h>

#include <appbase/application.hpp>

#include <fc/io/sstream.hpp>
#include <fc/log/logger.hpp>
#include <fc/thread/thread.hpp>

#include <algorithm>
#include <chrono>
#include <exception>
#include <memory>
#include <mutex>
#include <optional>
#include <thread>
#include <set>
#include <map>
#include <regex>
#include <stdexcept>

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

// Kinds accepted by hive.app_request_table_vacuum, see hafd.vacuum_requests.
std::string vacuum_command_prefix(const std::string& kind)
{
  static const std::map<std::string, std::string> commands = {
    { "full", "VACUUM FULL ANALYZE " },
    { "vacuum", "VACUUM (ANALYZE) " },
    { "analyze", "ANALYZE " },
    { "freeze", "VACUUM (FREEZE, ANALYZE) " }
  };
  const auto it = commands.find(kind);
  if (it == commands.end())
    throw std::invalid_argument("Unknown vacuum kind: " + kind);
  return it->second;
}

// A 'full' request for a table that an application writes in every long transaction is rarely granted its
// lock within VACUUM_LOCK_TIMEOUT, so the wait doubles with every consecutive skip, and once the request has
// been skipped for long enough, hived waits for the lock however long the sessions queued behind it wait.
const std::chrono::milliseconds MAX_ESCALATED_LOCK_TIMEOUT = std::chrono::seconds(60);
const std::chrono::seconds UNLIMITED_LOCK_WAIT_AFTER = std::chrono::minutes(30);

std::chrono::milliseconds vacuum_request_lock_timeout(int64_t skip_count, std::chrono::seconds skipped_for)
{
  if (skipped_for >= UNLIMITED_LOCK_WAIT_AFTER)
    return std::chrono::milliseconds::zero();
  std::chrono::milliseconds lock_timeout = VACUUM_LOCK_TIMEOUT;
  for (int64_t i = 0; i < skip_count && lock_timeout < MAX_ESCALATED_LOCK_TIMEOUT; ++i)
    lock_timeout *= 2;
  return std::min(lock_timeout, MAX_ESCALATED_LOCK_TIMEOUT);
}

const fc::microseconds POLL_INTERVAL = fc::seconds(10);
const fc::microseconds MIN_RECONNECT_DELAY = fc::seconds(1);
const fc::microseconds MAX_RECONNECT_DELAY = fc::seconds(60);

void sleep_unless_interrupted(appbase::application& app, fc::microseconds duration)
{
  const fc::time_point wake_up = fc::time_point::now() + duration;
  while (!app.is_interrupt_request() && fc::time_point::now() < wake_up)
    fc::usleep(std::min(fc::microseconds(fc::seconds(1)), wake_up - fc::time_point::now()));
}

// libpqxx reports most lost connections as broken_connection, but a query cut off
// mid-flight can surface as another pqxx error with the connection already closed.
bool is_connection_lost(const pqxx::connection& conn, const std::exception& e)
{
  return dynamic_cast<const pqxx::broken_connection*>(&e) != nullptr || !conn.is_open();
}

// Must be called from a catch block; reports a lost connection as broken_connection.
void rethrow_if_connection_lost(const pqxx::connection& conn, const std::exception& e)
{
  if (dynamic_cast<const pqxx::broken_connection*>(&e) != nullptr)
    throw;
  if (!conn.is_open())
    throw pqxx::broken_connection(e.what());
}

// A failed CREATE INDEX CONCURRENTLY leaves behind an invalid index.
// Drop it and reset status so the poller retries on the next cycle.
void reset_failed_index(pqxx::nontransaction& tx, const std::string& table_name, const std::string& index_constraint_name)
{
  std::string schema = table_name.substr(0, table_name.find('.'));
  std::string drop_cmd = "DROP INDEX IF EXISTS " + schema + "." + index_constraint_name + ";";
  wlog("Dropping invalid index after failed creation: ${cmd}", ("cmd", drop_cmd));
  tx.exec(drop_cmd);
  std::string reset_status =
    "UPDATE hafd.indexes_constraints SET status = 'missing' WHERE index_constraint_name ='" + index_constraint_name + "';";
  wlog("Resetting index status to missing for retry: ${index}", ("index", index_constraint_name));
  tx.exec(reset_status);
}

struct index_builds_state
{
  std::mutex mtx;
  std::set<std::string> finished_tables;
  // index_constraint_name -> table_name of builds whose connection was lost before
  // their 'creating' status could be reset; the monitor resets them once it can.
  std::map<std::string, std::string> indexes_to_reset;
};

void build_missing_indexes(const std::string& db_url, const std::string& table_name, index_builds_state& state)
{
  std::string thread_name = table_name;
  if (thread_name.size() > 16)
    thread_name.resize(16);
  fc::set_thread_name(thread_name.c_str());
  fc::thread::current().set_name(thread_name);

  try
  {
    pqxx::connection conn(db_url);
    pqxx::nontransaction tx(conn);
    pqxx::result data = tx.exec("SELECT index_constraint_name, command FROM hafd.indexes_constraints WHERE status = 'missing' AND table_name = '" + table_name + "';");
    for (const auto& index : data) //iterate over missing indexes and create them concurrently
    {
      std::string index_constraint_name = index["index_constraint_name"].as<std::string>();
      try
      {
        std::string original_command = index["command"].as<std::string>();
        std::regex create_index_regex(R"((CREATE\s+UNIQUE\s+INDEX|CREATE\s+INDEX))", std::regex::icase);
        std::string command = std::regex_replace(original_command, create_index_regex, "$& CONCURRENTLY");
        std::string update_table =
          "UPDATE hafd.indexes_constraints SET status = 'creating' WHERE index_constraint_name ='" + index_constraint_name + "';";
        ilog("SQL: ${update_table}",(update_table));
        tx.exec(update_table);
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
        elog("Error while creating index: ${e}", ("e", e.what()));
        if (is_connection_lost(conn, e))
        {
          std::lock_guard g(state.mtx);
          state.indexes_to_reset[index_constraint_name] = table_name;
          throw;
        }
        try
        {
          reset_failed_index(tx, table_name, index_constraint_name);
        }
        catch (const std::exception& cleanup_error)
        {
          elog("Error during index cleanup after failed creation: ${e}", ("e", cleanup_error.what()));
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
  }
  catch (const std::exception& e)
  {
    wlog("Index creation for table ${table_name} stopped: ${e}. Its remaining indexes will be retried on a later poll.", (table_name)("e", e.what()));
  }

  std::lock_guard g(state.mtx);
  state.finished_tables.insert(table_name);
  ilog("Thread for table: ${table_name} has been marked for deletion", (table_name));
}

// Owns the index build threads started by the monitor. Builds share their state
// by shared_ptr, so when the monitor exits by exception they are detached rather
// than joined: a long CREATE INDEX CONCURRENTLY must not delay the shutdown request.
class index_build_threads
{
public:
  index_build_threads() : _state(std::make_shared<index_builds_state>()) {}
  index_build_threads(const index_build_threads&) = delete;
  index_build_threads& operator=(const index_build_threads&) = delete;

  ~index_build_threads()
  {
    const bool unwinding = std::uncaught_exceptions() > 0;
    for (auto& [table_name, thread] : _threads)
    {
      if (!thread.joinable())
        continue;
      if (unwinding)
      {
        wlog("Leaving index creation for table ${table_name} running in the background.", (table_name));
        thread.detach();
      }
      else
      {
        ilog("Joining thread for table: ${table_name}", ("table_name", table_name));
        thread.join();
      }
    }
  }

  bool is_running(const std::string& table_name) const
  {
    const auto it = _threads.find(table_name);
    return it != _threads.end() && it->second.joinable();
  }

  void start(std::string db_url, const std::string& table_name)
  {
    _threads[table_name] = std::thread([state = _state, db_url = std::move(db_url), table_name]()
    {
      build_missing_indexes(db_url, table_name, *state);
    });
  }

  void join_finished()
  {
    std::lock_guard g(_state->mtx);
    for (const auto& table_name : _state->finished_tables)
    {
      if (_threads[table_name].joinable())
      {
        ilog("Joining thread for table: ${table_name}", ("table_name", table_name));
        _threads[table_name].join();
      }
      _threads.erase(table_name);
    }
    _state->finished_tables.clear();
  }

  std::map<std::string, std::string> indexes_to_reset() const
  {
    std::lock_guard g(_state->mtx);
    return _state->indexes_to_reset;
  }

  void index_was_reset(const std::string& index_constraint_name)
  {
    std::lock_guard g(_state->mtx);
    _state->indexes_to_reset.erase(index_constraint_name);
  }

private:
  std::shared_ptr<index_builds_state> _state;
  std::map<std::string, std::thread> _threads; // Used only by the monitor thread
};

void reset_interrupted_index_builds(pqxx::connection& conn, pqxx::nontransaction& tx)
{
  try
  {
    dlog("Resetting indexes creation states before polling loop...");
    tx.exec("UPDATE hafd.indexes_constraints SET status = 'missing' WHERE status = 'creating';");
  }
  catch (const std::exception& e)
  {
    rethrow_if_connection_lost(conn, e);
    elog("Error while resetting indexes creation states: ${e}", ("e", e.what()));
  }
}

void reset_indexes_of_lost_builds(pqxx::connection& conn, pqxx::nontransaction& tx, index_build_threads& builds)
{
  for (const auto& [index_constraint_name, table_name] : builds.indexes_to_reset())
  {
    try
    {
      reset_failed_index(tx, table_name, index_constraint_name);
      builds.index_was_reset(index_constraint_name);
    }
    catch (const std::exception& e)
    {
      rethrow_if_connection_lost(conn, e);
      elog("Error while resetting index ${index} after its build lost the database connection: ${e}", ("index", index_constraint_name)("e", e.what()));
    }
  }
}

void process_vacuum_requests(pqxx::connection& conn, pqxx::nontransaction& tx)
{
  dlog("Checking for table vacuum requests...");
  try
  {
    // 'full' rewrites the table and drops its visibility map, so it must precede any other kind on the same table.
    pqxx::result data = tx.exec(
      "SELECT schema_name, table_name, kind, skip_count, "
      "COALESCE(EXTRACT(EPOCH FROM NOW()::timestamp - first_skip_time)::bigint, 0) AS skipped_for_seconds "
      "FROM hafd.vacuum_requests WHERE status = 'requested' "
      "ORDER BY schema_name, table_name, kind <> 'full', kind;"
    );
    dlog("Found ${count} tables with vacuum requests.", ("count", data.size()));

    std::string locked_table;
    for (const auto& record : data)
    {
      std::string schema_name;
      std::string table_name;
      std::string kind;
      try
      {
        schema_name = record["schema_name"].as<std::string>();
        table_name = record["table_name"].as<std::string>();
        kind = record["kind"].as<std::string>();
        std::string qualified_table_name = tx.quote_name(schema_name) + "." + tx.quote_name(table_name);
        std::string vacuum_command = vacuum_command_prefix(kind) + qualified_table_name;

        // A skipped 'full' must stay ahead of the table's other kinds, so they wait for the next poll too.
        if (qualified_table_name == locked_table)
        {
          dlog("Postponed ${vacuum_command} until ${table} is unlocked", (vacuum_command)("table", qualified_table_name));
          continue;
        }

        const int64_t skip_count = record["skip_count"].as<int64_t>();
        const std::chrono::seconds skipped_for(record["skipped_for_seconds"].as<int64_t>());
        const std::chrono::milliseconds lock_timeout = vacuum_request_lock_timeout(skip_count, skipped_for);

        ilog("Performing vacuum: ${vacuum_command} (lock wait ${t} ms, 0 = unlimited)", (vacuum_command)("t", lock_timeout.count()));
        auto start_time = fc::time_point::now();
        if (!vacuum_unless_locked(tx, vacuum_command, lock_timeout))
        {
          locked_table = qualified_table_name;
          tx.exec_params(
            "UPDATE hafd.vacuum_requests SET skip_count = skip_count + 1, first_skip_time = COALESCE(first_skip_time, NOW()) "
            "WHERE schema_name = $1 AND table_name = $2 AND kind = $3",
            schema_name,
            table_name,
            kind
          );
          wlog("Vacuum request ${vacuum_command} has now been skipped ${n} times in a row, over ${s} seconds",
            (vacuum_command)("n", skip_count + 1)("s", skipped_for.count()));
          continue;
        }
        auto end_time = fc::time_point::now();
        fc::microseconds vacuum_duration = end_time - start_time;
        ilog("Vacuumed table: ${schema}.${table} in ${duration} seconds, after ${n} skips over ${s} seconds",
          ("schema", schema_name)("table", table_name)("duration", vacuum_duration.to_seconds())("n", skip_count)("s", skipped_for.count()));

        tx.exec_params(
          "UPDATE hafd.vacuum_requests SET status = 'vacuumed', last_vacuumed_time = NOW(), error_message = NULL, skip_count = 0, first_skip_time = NULL "
          "WHERE schema_name = $1 AND table_name = $2 AND kind = $3",
          schema_name,
          table_name,
          kind
        );
        ilog("Updated vacuum status for table: ${schema}.${table}", ("schema", schema_name)("table", table_name));
      }
      catch (const std::exception& e)
      {
        rethrow_if_connection_lost(conn, e);
        elog("Error while vacuuming table: ${schema}.${table}: ${e}", ("schema", schema_name)("table", table_name)("e", e.what()));

        try
        {
          std::string error_msg = e.what();

          tx.exec_params(
            "UPDATE hafd.vacuum_requests SET status = 'failed', error_message = $1, skip_count = 0, first_skip_time = NULL "
            "WHERE schema_name = $2 AND table_name = $3 AND kind = $4",
            error_msg,
            schema_name,
            table_name,
            kind
          );
        }
        catch (const std::exception& update_error)
        {
          rethrow_if_connection_lost(conn, update_error);
          elog("Error while updating vacuum failure status for table ${schema}.${table}: ${e}", ("schema", schema_name)("table", table_name)("e", update_error.what()));
        }
      }
    }
  }
  catch (const std::exception& e)
  {
    rethrow_if_connection_lost(conn, e);
    elog("Error while checking for vacuum requests: ${e}", ("e", e.what()));
  }
}

// Check for tables with missing indexes that are not currently being created
void start_missing_index_builds(pqxx::connection& conn, pqxx::nontransaction& tx, index_build_threads& builds, const std::string& db_url)
{
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
      if (builds.is_running(table_name))
      {
        ilog("A thread is already running for table: ${table_name}", ("table_name", table_name));
        continue; //check the next table
      }

      ilog("NOTE: Starting a new thread to create indexes for table: ${table_name}", ("table_name", table_name));
      builds.start(db_url, table_name);
    } //end for tables with missing indexes
    dlog("Finished polling for tables with missing indexes, sleep for 10s.");
  }
  catch (const std::exception& e)
  {
    rethrow_if_connection_lost(conn, e);
    elog("Error while checking for missing indexes: ${e}", ("e", e.what()));
  }
}

}

massive_index_policy parse_massive_index_policy( const std::string& name )
{
  if ( name == to_string( massive_index_policy::drop_all ) )
    return massive_index_policy::drop_all;
  if ( name == to_string( massive_index_policy::keep_monotonic ) )
    return massive_index_policy::keep_monotonic;
  throw std::invalid_argument( "Unknown massive index policy: " + name + ", expected drop-all or keep-monotonic" );
}

const char* to_string( massive_index_policy policy )
{
  switch ( policy )
  {
    case massive_index_policy::drop_all:
      return "drop-all";
    case massive_index_policy::keep_monotonic:
      return "keep-monotonic";
  }
  throw std::invalid_argument( "Unknown massive index policy" );
}

indexes_controler::indexes_controler( std::string db_url, uint32_t psql_index_threshold, uint32_t monitor_retry_budget_seconds, massive_index_policy index_policy, appbase::application& app )
: _db_url( std::move(db_url) )
, _psql_index_threshold( psql_index_threshold )
, _monitor_retry_budget_seconds( monitor_retry_budget_seconds )
, _index_policy( index_policy )
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

  ilog( "Number of blocks to sync is greater than threshold for disabling indexes. Indexes will be dropped with policy ${p}. ${n}<${t}",("p", to_string( _index_policy ))("n", number_of_blocks_to_insert )("t", _psql_index_threshold ) );
  auto processor = start_commit_sql(false, std::string( "hive.disable_indexes_of_irreversible( '" ) + to_string( _index_policy ) + "' )", "disable indexes" );
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

  vacuum_account_operations();

  fc::time_point cluster_start_time = fc::time_point::now();
  fc::microseconds restore_indexes_time = cluster_start_time - restore_indexes_start_time;
  ilog( "PROFILE: Restored HAF table indexes: ${t}s", ("t",restore_indexes_time.to_seconds()) );
}

void
indexes_controler::vacuum_account_operations() {
  if (theApp.is_interrupt_request())
    return;

  // CLUSTER rewrites hafd.account_operations without a visibility map and the table is insert-only,
  // so autovacuum would not build one for weeks; until then every index-only scan fetches heap rows.
  // VACUUM cannot run inside a transaction, hence it is issued here instead of in hive.restore_indexes.
  // ANALYZE rides along: it replaces the one hive.recluster_account_operations_if_index_dropped ran after CLUSTER.
  const std::string vacuum_command = "VACUUM (FREEZE, ANALYZE) hafd.account_operations";
  ilog("Performing vacuum: ${vacuum_command}", (vacuum_command));
  pqxx::connection conn(db_url_with_hived_app(_db_url));
  pqxx::nontransaction tx(conn);
  const auto start_time = fc::time_point::now();
  tx.exec(vacuum_command);
  fc::microseconds vacuum_duration = fc::time_point::now() - start_time;
  ilog("PROFILE: Vacuumed hafd.account_operations: ${t}s", ("t", vacuum_duration.to_seconds()));
}

bool
indexes_controler::disable_constraints( uint32_t number_of_blocks_to_insert ) {
  if (theApp.is_interrupt_request())
    return false;

  if ( number_of_blocks_to_insert <= _psql_index_threshold )
  {
    ilog( "Number of blocks to add is less than threshold for disabling constraints. Constraints won't be dropped. ${n}<=${t}",("n", number_of_blocks_to_insert )("t", _psql_index_threshold ) );
    return false;
  }

  auto processor = start_commit_sql(false, "hive.disable_fk_of_irreversible()", "disable fk-s" );
  processor->join();
  ilog( "All irreversible blocks tables foreign keys are dropped" );
  return true;
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
  const std::string thread_name = "haf_monitor";
  fc::set_thread_name(thread_name.c_str());
  fc::thread::current().set_name(thread_name);

  const std::string db_url = db_url_with_hived_app_as_haf_maintainer(_db_url);
  const fc::microseconds retry_budget = fc::seconds(_monitor_retry_budget_seconds);
  index_build_threads builds;
  std::unique_ptr<pqxx::connection> conn;
  bool interrupted_builds_reset = false;
  std::optional<fc::time_point> failing_since;
  fc::microseconds reconnect_delay = MIN_RECONNECT_DELAY;

  while (!theApp.is_interrupt_request())
  {
    bool connection_lost = false;
    try
    {
      if (!conn)
        conn = std::make_unique<pqxx::connection>(db_url);
      {
        pqxx::nontransaction tx(*conn);
        if (!interrupted_builds_reset)
        {
          reset_interrupted_index_builds(*conn, tx);
          interrupted_builds_reset = true;
        }
        reset_indexes_of_lost_builds(*conn, tx, builds);
        process_vacuum_requests(*conn, tx);
        start_missing_index_builds(*conn, tx, builds, db_url);
      }

      if (failing_since)
      {
        ilog("Index monitor reconnected to the database after ${s} seconds; polling resumed.", ("s", (fc::time_point::now() - *failing_since).to_seconds()));
        failing_since.reset();
        reconnect_delay = MIN_RECONNECT_DELAY;
      }
    }
    catch (const pqxx::broken_connection& e)
    {
      conn.reset();
      const fc::time_point now = fc::time_point::now();
      if (!failing_since)
        failing_since = now;
      const fc::microseconds failing_for = now - *failing_since;
      if (failing_for >= retry_budget)
        throw std::runtime_error(
          "Index monitor could not use its database connection for " + std::to_string(failing_for.to_seconds()) +
          " seconds, exhausting its retry budget of " + std::to_string(retry_budget.to_seconds()) +
          " seconds (psql-index-monitor-retry-budget); last error: " + e.what());

      wlog("Index monitor has no usable database connection: ${e}. Reconnecting in ${d} seconds (failing for ${f} of ${b} seconds allowed).",
        ("e", e.what())("d", reconnect_delay.to_seconds())("f", failing_for.to_seconds())("b", retry_budget.to_seconds()));
      connection_lost = true;
    }

    // fc refuses to yield the fiber while an exception is being handled, so never sleep inside a catch.
    if (connection_lost)
    {
      sleep_unless_interrupted(theApp, reconnect_delay);
      reconnect_delay = std::min(reconnect_delay + reconnect_delay, MAX_RECONNECT_DELAY);
    }
    else
      sleep_unless_interrupted(theApp, POLL_INTERVAL);

    builds.join_finished();
  }
  ilog("Interrupt request received, stopping polling for tables with missing indexes.");
} //end poll_and_create_indexes

}}} // namespace hive{ plugins { sql_serializer
