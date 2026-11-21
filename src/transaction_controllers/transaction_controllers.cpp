#include "include/transactions_controller/transaction_controllers.hpp"

#include <appbase/application.hpp>

#include <fc/exception/exception.hpp>

#include <atomic>
#include <chrono>
#include <mutex>
#include <optional>
#include <string>
#include <thread>

namespace transaction_controllers {

namespace {

std::atomic<std::chrono::seconds::rep> recovery_wait_seconds{0};

const unsigned int MAX_RETRY_COUNT = 100;
const std::chrono::milliseconds RETRY_DELAY{500};
const std::chrono::seconds RECOVERY_RETRY_DELAY{2};
const std::chrono::seconds RECOVERY_LOG_INTERVAL{30};
const unsigned int MAX_TRANSACTION_RUNS = 10;

const std::string INVALID_PARAMETER_VALUE = "22023";

// The server ends a session with these: 57P01 admin_shutdown, 57P02 crash_shutdown (another backend crashed and the
// postmaster resets), 57P03 cannot_connect_now.
bool is_session_terminated(const pqxx::failure& e)
{
  const auto* sql_error = dynamic_cast<const pqxx::sql_error*>(&e);
  if (sql_error == nullptr)
    return false;
  const std::string sqlstate = sql_error->sqlstate();
  return sqlstate == "57P01" || sqlstate == "57P02" || sqlstate == "57P03";
}

// libpqxx reports most lost connections as broken_connection, but a statement cut off
// mid-flight can surface as another pqxx error with the connection already closed.
bool is_connection_lost(const pqxx::connection* connection, const pqxx::failure& e)
{
  return dynamic_cast<const pqxx::broken_connection*>(&e) != nullptr
    || is_session_terminated(e)
    || (connection != nullptr && !connection->is_open());
}

// A server starting up or replaying its WAL after a crash refuses connections with SQLSTATE 57P03,
// which libpq reports only as the text of the error.
bool is_database_recovering(const std::string& failure)
{
  static const char* const RECOVERY_MESSAGES[] = {
    "the database system is starting up",
    "the database system is in recovery mode",
    "the database system is not yet accepting connections",
  };
  for (const char* message : RECOVERY_MESSAGES)
    if (failure.find(message) != std::string::npos)
      return true;
  return false;
}

/// Decides, for one statement, whether its lost connection is retried: while the database recovers, until the
/// recovery wait has passed since the first failure; after any other failure, MAX_RETRY_COUNT times.
class reconnect_wait
{
public:
  reconnect_wait(const std::string& description, const std::string& url, appbase::application& app)
    : _description(description), _url(url), _app(app) {}

  /// Sleeps before the next attempt, or throws pqxx::broken_connection when none is left.
  void after_failure(const std::string& failure)
  {
    using clock = std::chrono::steady_clock;
    const auto now = clock::now();
    if (!_first_failure)
      _first_failure = now;
    const std::chrono::seconds recovery_wait{recovery_wait_seconds.load()};
    const auto failing_for = std::chrono::duration_cast<std::chrono::seconds>(now - *_first_failure);

    std::chrono::milliseconds delay = RETRY_DELAY;
    if (recovery_wait.count() > 0 && is_database_recovering(failure))
    {
      if (failing_for >= recovery_wait)
      {
        elog("Transaction controller: `${d}': PostgreSQL did not finish starting up or recovering within ${w} seconds (psql-recovery-wait); last error: ${e}. Exiting.",
          ("d", _description)("w", recovery_wait.count())("e", failure));
        throw pqxx::broken_connection(failure);
      }
      if (!_last_recovery_log || now - *_last_recovery_log >= RECOVERY_LOG_INTERVAL)
      {
        wlog("Transaction controller: `${d}' is waiting for PostgreSQL to finish starting up or recovering (${f} of ${w} seconds allowed by psql-recovery-wait): ${e}",
          ("d", _description)("f", failing_for.count())("w", recovery_wait.count())("e", failure));
        _last_recovery_log = now;
      }
      delay = RECOVERY_RETRY_DELAY;
    }
    else
    {
      wlog("Transaction controller: `${d}' lost connection to database: `${url}'. Retrying # ${r}...", ("d", _description)("url", _url)("r", _retries));
      if (++_retries >= MAX_RETRY_COUNT)
      {
        elog("Transaction controller: `${d}' permanently lost connection to database: `${url}'. Exiting.", ("d", _description)("url", _url));
        throw pqxx::broken_connection(failure);
      }
    }

    if (_app.is_interrupt_request())
    {
      elog("Transaction controller: `${d}' lost connection to database: `${url}' during shutdown. Exiting.", ("d", _description)("url", _url));
      throw pqxx::broken_connection(failure);
    }

    /// Give a chance to restart server or somehow "repair" it
    std::this_thread::sleep_for(delay);
  }

private:
  const std::string& _description;
  const std::string& _url;
  appbase::application& _app;
  std::optional<std::chrono::steady_clock::time_point> _first_failure;
  std::optional<std::chrono::steady_clock::time_point> _last_recovery_log;
  unsigned int _retries = 0;
};

////////////////////////////////////////////////////////////////////////////////////////////////////
///                 Own transaction controler (thread/connection specific)                       ///
////////////////////////////////////////////////////////////////////////////////////////////////////

class own_tx_controller final : public transaction_controller
{
public:
  own_tx_controller(std::string dbUrl, std::string description, appbase::application& app) : _dbUrl(std::move(dbUrl)), _description(std::move(description)), _theApp(app) {}

/// transaction_controller:
  transaction_ptr openTx() override;
  void disconnect() override;

private:

  class own_transaction final : public transaction
  {
  public:
    explicit own_transaction(own_tx_controller* owner) : _owner(owner)
    {
      FC_ASSERT(_owner->_own_tx == nullptr);
      _owner->_own_tx = this;

      with_retry([]() -> void
        {
        /// Nothing to do here - transaction will opened inside reconnect
        }
      );
    }

    ~own_transaction() override
    {
      do_rollback();
    }

    void commit() override;
    pqxx::result exec(const std::string& query) override;
    void run_in_transaction(std::function<void(pqxx::work&)>) override;
    void rollback() override;

  private:
    /// Reconnects and runs `ex` again only while the transaction has executed nothing: once it has, the server
    /// rolled its work back with the lost connection, so the caller has to run the whole transaction again.
    template <typename Executor>
    auto with_retry(Executor ex) -> decltype(ex())
    {
      if (_lost)
        throw transaction_lost("Transaction controller: `" + _owner->_description + "' already lost the connection of this transaction");

      reconnect_wait wait(_owner->_description, _owner->_dbUrl, _owner->get_app());
      for (;;)
      {
        std::string failure;
        try
        {
          if(_owner->_opened_connection == nullptr) {
            do_reconnect();
          }

          if ( _opened_tx == nullptr ) {
            _opened_tx = std::make_unique<pqxx::work>(*_owner->_opened_connection);
          }
          return ex();
        }
        catch(const pqxx::failure& e)
        {
          if (!is_connection_lost(_owner->_opened_connection.get(), e))
            throw;
          failure = e.what();
          drop_connection();
        }

        if (_executed)
          lose(failure, std::nullopt);

        wait.after_failure(failure);
      }
    }

    void drop_connection()
    {
      _opened_tx.reset();
      if(_owner->_opened_connection != nullptr)
      {
        _owner->_opened_connection->close();
        _owner->_opened_connection.release();
      }
      else
      {
        dlog("Not closing connection, because it was not set");
      }
    }

    [[noreturn]] void lose(const std::string& failure, std::optional<std::string> commit_xid)
    {
      _lost = true;
      drop_connection();
      wlog("Transaction controller: `${d}' lost connection to database: `${url}' in the middle of a transaction: ${e}", ("d", _owner->_description)("url", _owner->_dbUrl)("e", failure));
      throw transaction_lost(failure, std::move(commit_xid));
    }

    void do_reconnect()
    {
      try
      {
        _opened_tx.reset();
        if(_owner->_opened_connection != nullptr)
        {
          _owner->_opened_connection->close();
          _owner->_opened_connection.release();
        }
      }
      catch(const pqxx::failure& ex)
      {
        ilog("Ignoring a pqxx exception during an implicit disconnect forced by reconnect request: ${e}", ("e", ex.what()));
      }

      dlog("Trying to connect to database: `${url}'...", ("url", _owner->_dbUrl));
      _owner->_opened_connection = std::make_unique<pqxx::connection>(_owner->_dbUrl);
      dlog("Connected to database: `${url}'.", ("url", _owner->_dbUrl));
    }

    void finalize_transaction()
    {
      if(_owner != nullptr)
      {
        FC_ASSERT(_owner->_own_tx == this);
        _owner->_own_tx = nullptr;
        _owner = nullptr;
      }
    }

    void do_rollback()
    {
      if(_opened_tx)
      {
        _opened_tx->abort();
        _opened_tx.reset();
      }
      
      finalize_transaction();
    }

  private:
    own_tx_controller*          _owner;
    std::unique_ptr<pqxx::work> _opened_tx;
    bool                        _executed = false;
    bool                        _lost = false;
  }; //own_transaction

private:
  const std::string _dbUrl;
  const std::string _description;
  appbase::application& _theApp;

  std::unique_ptr<pqxx::connection> _opened_connection;
  own_transaction *_own_tx = nullptr;

public:

  appbase::application& get_app()
  {
    return _theApp;
  }
};


void own_tx_controller::own_transaction::commit()
{
  if(_opened_tx)
  {
    std::optional<std::string> xid;
    if (_executed)
    {
      try
      {
        const pqxx::result id = _opened_tx->exec("SELECT txid_current_if_assigned()");
        if (!id[0][0].is_null())
          xid = id[0][0].c_str();
      }
      catch(const pqxx::failure& e)
      {
        if (!is_connection_lost(_owner->_opened_connection.get(), e))
          throw;
        lose(e.what(), std::nullopt);
      }
    }

    try
    {
      _opened_tx->commit();
    }
    catch(const pqxx::in_doubt_error& e)
    {
      lose(e.what(), xid);
    }
    catch(const pqxx::failure& e)
    {
      if (!is_connection_lost(_owner->_opened_connection.get(), e))
        throw;
      lose(e.what(), xid);
    }
    _opened_tx.reset();
  }

  finalize_transaction();
}

pqxx::result own_tx_controller::own_transaction::exec(const std::string& query)
{
  pqxx::result result = with_retry([this, &query]() -> pqxx::result
    {
      FC_ASSERT(_opened_tx, "No transaction opened");

      return _opened_tx->exec(query);
    }
  );
  _executed = true;
  return result;
}

void own_tx_controller::own_transaction::run_in_transaction(std::function<void(pqxx::work&)> func)
{
  with_retry([this, &func]() {
    FC_ASSERT(_opened_tx, "No transaction opened");
    func(*_opened_tx);
  });
  _executed = true;
}

void own_tx_controller::own_transaction::rollback()
{
  do_rollback();
}

transaction_controller::transaction_ptr own_tx_controller::openTx()
{
  return std::make_unique<own_transaction>(this);
}

void own_tx_controller::disconnect()
{
  if(_opened_connection)
  {
    if(_own_tx != nullptr) {
      _own_tx->rollback();
    }

    _opened_connection->close();
    _opened_connection.release();
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////
///  Single transaction controler (sharing connection and executing SQL commands sequentially)   ///
////////////////////////////////////////////////////////////////////////////////////////////////////

class single_transaction_controller : public transaction_controller
{
public:
  explicit single_transaction_controller(const std::string& dbUrl, appbase::application& app) : _clientCount(0)
  {
    _own_contoller = build_own_transaction_controller(dbUrl, "single_transaction_controller", app);
  }

/// transaction_controller:
  transaction_ptr openTx() override;
  void disconnect() override;

  void initialize_tx()
  {
    ++_clientCount;
    if(_clientCount == 1)
    {
      FC_ASSERT(_own_tx == nullptr, "Only single transaction allowed");
      _own_tx = _own_contoller->openTx();
    }
  }

  unsigned int finalize_tx()
  {
    --_clientCount;
    if(_clientCount == 0 && _own_tx) {
      _own_tx.reset();
    }

    return _clientCount;
  }

  pqxx::result do_query(const std::string& query)
  {
    if(_own_tx) {
      return _own_tx->exec(query);
    }

    return pqxx::result();
  }

  void do_run_in_transaction(std::function<void(pqxx::work&)> func)
  {
    if (_own_tx)
      return _own_tx->run_in_transaction(func);
  }

  void do_commit()
  {
    if(_clientCount == 1 && _own_tx)
    {
      _own_tx->commit();
      _own_tx.reset();
    }
  }

  void do_rollback()
  {
    if(_own_tx)
    {
      _own_tx->rollback();
      _own_tx.reset();
    }
  }

private:
  /// Represents a fake transaction object which always delegates calls to the actual one.
  /// Also, by using dedicated mutex prevents on multiple calls made to exec between openTx/disconnect calls pair.
  class transaction_wrapper final : public transaction
  {
  public:
    transaction_wrapper(single_transaction_controller& owner, std::mutex& mtx) :
      _owner(owner), _locked_transaction(mtx), _do_implicit_rollback(true)
      {
        _owner.initialize_tx();
      }

    ~transaction_wrapper() override;

    void commit() override;
    pqxx::result exec(const std::string& query) override;
    void run_in_transaction(std::function<void(pqxx::work&)>) override;
    void rollback() override;

  private:
    single_transaction_controller& _owner;
    std::unique_lock<std::mutex> _locked_transaction;
    bool _do_implicit_rollback;
  };

private:
  transaction_controller_ptr _own_contoller;
  transaction_ptr _own_tx;
  std::atomic_uint _clientCount;
  std::mutex _lock;
};

void single_transaction_controller::transaction_wrapper::commit()
{
  _owner.do_commit();
  _do_implicit_rollback = false;
}

pqxx::result single_transaction_controller::transaction_wrapper::exec(const std::string& query)
{
  return _owner.do_query(query);
}

void single_transaction_controller::transaction_wrapper::run_in_transaction(std::function<void(pqxx::work&)> func)
{
  _owner.do_run_in_transaction(func);
}

void single_transaction_controller::transaction_wrapper::rollback()
{
  _owner.do_rollback();
  _do_implicit_rollback = false;
}

single_transaction_controller::transaction_wrapper::~transaction_wrapper()
{
  if(_do_implicit_rollback) {
    _owner.do_rollback();
  }

  _owner.finalize_tx();
}


transaction_controller::transaction_ptr single_transaction_controller::openTx()
{
  return std::make_unique<transaction_wrapper>(*this, _lock);
}

void single_transaction_controller::disconnect()
{
  /// If multiple clients use this controller, let them finish their work...
  if(_clientCount == 0 && _own_contoller) {
    _own_contoller->disconnect();
  }
}


// Reads the outcome of a transaction whose connection was lost while committing it.
bool is_committed(transaction_controller& controller, const std::string& xid)
{
  auto tx = controller.openTx();
  pqxx::result status;
  try
  {
    status = tx->exec("SELECT txid_status(" + xid + ")");
  }
  catch(const pqxx::sql_error& e)
  {
    // "transaction ID is in the future": the crash took the transaction with the WAL the server had not flushed yet
    if (e.sqlstate() != INVALID_PARAMETER_VALUE)
      throw;
    return false;
  }
  tx->commit();

  const pqxx::field field = status[0][0];
  const std::string outcome = field.is_null() ? "unknown" : field.c_str();
  if (outcome == "committed")
    return true;
  if (outcome == "aborted")
    return false;
  throw pqxx::failure("Cannot tell whether transaction " + xid + ", whose connection was lost while committing it, committed: its status is " + outcome);
}

} // namespace

void set_recovery_wait(std::chrono::seconds wait)
{
  recovery_wait_seconds.store(wait.count());
}

void run_transaction(transaction_controller& controller, const std::function<void(transaction&)>& unit)
{
  for (unsigned int run = 1;; ++run)
  {
    std::optional<transaction_lost> lost;
    try
    {
      auto tx = controller.openTx();
      unit(*tx);
      tx->commit();
      return;
    }
    catch(const transaction_lost& e)
    {
      lost = e;
    }

    if (lost->commit_xid() && is_committed(controller, *lost->commit_xid()))
    {
      ilog("Transaction ${x}, whose connection was lost while committing it, did commit.", ("x", *lost->commit_xid()));
      return;
    }
    if (run >= MAX_TRANSACTION_RUNS)
    {
      elog("A transaction lost its connection to the database ${n} times in a row; giving up: ${e}", ("n", run)("e", lost->what()));
      throw *lost;
    }
    wlog("Running again, from its start, a transaction whose connection to the database was lost (run ${r} of at most ${m}).", ("r", run + 1)("m", MAX_TRANSACTION_RUNS));
  }
}

transaction_controller_ptr build_own_transaction_controller(const std::string& dbUrl, const std::string& description, appbase::application& app)
{
  return std::make_shared<own_tx_controller>(dbUrl, description, app);
}

transaction_controller_ptr build_single_transaction_controller(const std::string& dbUrl, appbase::application& app)
{
  return std::make_shared<single_transaction_controller>(dbUrl, app);
}

} // namespace transaction_controllers
