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

void indexes_interruptor::run() {
  try {
    while (!_stop.load(std::memory_order_relaxed)) {
      if (_app.is_interrupt_request()) {
        try {
          wlog("Canceling index related queries...");
          pqxx::connection conn(_db_url);
          pqxx::nontransaction tx(conn);
          pqxx::result cancelled = tx.exec(
            "WITH targets AS ("
            "  SELECT pid, usename, client_addr, state, query "
            "  FROM pg_stat_activity "
            "  WHERE application_name = 'hived_index' "
            "    AND pid <> pg_backend_pid()"
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
            wlog("Cancelled connection pid=${pid} user='${user}' addr='${addr}' state='${state}' query='${query}'",
                 ("pid", pid)("user", user)("addr", addr)("state", state)("query", query));
          }
          wlog("Cancelled ${n} backend connections", ("n", cancelled_count));
        } catch (const std::exception& e) {
          elog("Failed to cancel index queries: ${e}", ("e", e.what()));
        }
        break;
      }
      fc::usleep(fc::seconds(1));
    }
  } catch (const std::exception& e) {
    wlog("indexes_interruptor thread error: ${e}", ("e", e.what()));
  }
}

} // namespace hive::plugins::sql_serializer
