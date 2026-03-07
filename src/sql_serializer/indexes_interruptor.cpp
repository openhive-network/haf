#include <hive/plugins/sql_serializer/indexes_interruptor.h>

#include <appbase/application.hpp>
#include <fc/log/logger.hpp>
#include <fc/thread/thread.hpp>
#include <pqxx/pqxx>

namespace hive::plugins::sql_serializer {

indexes_interruptor::indexes_interruptor(const std::string& db_url, appbase::application& app)
  : _db_url(db_url)
  , _app(app)
{
  _worker = std::thread([this]() { run(); });
}

indexes_interruptor::~indexes_interruptor() {
  _stop.store(true, std::memory_order_relaxed);
  if (_worker.joinable())
    _worker.join();
}

std::size_t indexes_interruptor::cancel_backends(const char* app_name) {
  pqxx::connection conn(_db_url);
  pqxx::nontransaction tx(conn);
  pqxx::result cancelled = tx.exec(
    "WITH targets AS ("
    "  SELECT pid, usename, client_addr, state, query "
    "  FROM pg_stat_activity "
    "  WHERE application_name = '" + std::string(app_name) + "' "
    "    AND pid <> pg_backend_pid()"
    "    AND datname = current_database()"
    "), cancels AS ("
    "  SELECT t.*, pg_cancel_backend(t.pid) AS cancelled FROM targets t"
    ")"
    "SELECT pid, usename, client_addr, state, query FROM cancels WHERE cancelled;"
  );
  std::size_t cancelled_count = 0;
  for (const auto& row : cancelled) {
    auto pid = row[0].as<int>();
    auto user = row[1].is_null() ? std::string("") : row[1].as<std::string>();
    auto addr = row[2].is_null() ? std::string("") : row[2].as<std::string>();
    auto state = row[3].is_null() ? std::string("") : row[3].as<std::string>();
    auto query = row[4].is_null() ? std::string("") : row[4].as<std::string>();
    ++cancelled_count;
    wlog("Cancelled [${app}] connection pid=${pid} user='${user}' addr='${addr}' state='${state}' query='${query}'",
         ("app", app_name)("pid", pid)("user", user)("addr", addr)("state", state)("query", query));
  }
  return cancelled_count;
}

void indexes_interruptor::run() {
  try {
    // Wait for interrupt request
    while (!_stop.load(std::memory_order_relaxed)) {
      if (_app.is_interrupt_request())
        break;
      fc::usleep(fc::seconds(5));
    }

    if (_stop.load(std::memory_order_relaxed))
      return;

    // Phase 1: Cancel index queries immediately (they are safe to cancel and can be very long-running)
    try {
      wlog("Phase 1: Canceling index-related queries...");
      auto n = cancel_backends("hived_index");
      wlog("Phase 1: Cancelled ${n} index backend(s)", ("n", n));
    } catch (const std::exception& e) {
      elog("Failed to cancel index queries: ${e}", ("e", e.what()));
    }

    // Phase 2: Give data dump threads a grace period to finish their current COPY batch,
    // then cancel them if they're still running. This prevents indefinite shutdown hangs
    // when a large COPY operation is in progress. Safety: if data dump threads are cancelled,
    // join_processors will throw, mark_irreversible_data_as_dirty(false) won't run, and
    // hived will re-replay on next startup.
    wlog("Phase 2: Waiting ${t}s grace period for data dump threads...", ("t", DATA_DUMP_GRACE_PERIOD_SECONDS));
    for (int i = 0; i < DATA_DUMP_GRACE_PERIOD_SECONDS; ++i) {
      if (_stop.load(std::memory_order_relaxed))
        return; // Clean shutdown completed during grace period
      fc::usleep(fc::seconds(1));
    }

    if (_stop.load(std::memory_order_relaxed))
      return; // Clean shutdown completed during grace period

    try {
      wlog("Phase 2: Grace period expired, canceling data dump queries...");
      auto n = cancel_backends("hived_data");
      wlog("Phase 2: Cancelled ${n} data dump backend(s)", ("n", n));
    } catch (const std::exception& e) {
      elog("Failed to cancel data dump queries: ${e}", ("e", e.what()));
    }
  } catch (const std::exception& e) {
    wlog("indexes_interruptor thread error: ${e}", ("e", e.what()));
  }
}

} // namespace hive::plugins::sql_serializer
