#pragma once

// C++ connector library for PostgreSQL (http://pqxx.org/development/libpqxx/)
#include <pqxx/pqxx>

#include <chrono>
#include <memory>
#include <functional>
#include <optional>
#include <string>

namespace appbase
{
  class application;
}

namespace transaction_controllers {

/**
   * @brief Represents opened internal transaction.
     Can be explicitly commited or rollbacked. If not explicitly committed, implicit rollback is performed at destruction time.
  */
class transaction
{
public:
  virtual void commit() = 0;
  virtual pqxx::result exec(const std::string& query) = 0;
  virtual void run_in_transaction(std::function<void(pqxx::work&)>) = 0;
  virtual void rollback() = 0;

  virtual ~transaction() {}
};

class transaction_controller
{
public:
  typedef std::unique_ptr<transaction> transaction_ptr;
  /// Opens internal transaction. \see transaction class for further description.
  virtual transaction_ptr openTx() = 0;
  /// Allows to explicitly disconnect from a database server. Asserts if there is any opened transaction by this controller.
  virtual void disconnect() = 0;
  
  virtual ~transaction_controller() {}
};

typedef std::shared_ptr<transaction_controller> transaction_controller_ptr;

/**
   * @brief The connection of a transaction was lost after the transaction executed statements.
     The server rolled the transaction back, unless the connection was lost while committing it: then commit_xid()
     holds the transaction's id (txid_current) and whether it committed is unknown.
  */
class transaction_lost : public pqxx::broken_connection
{
public:
  explicit transaction_lost(const std::string& what, std::optional<std::string> commit_xid = std::nullopt)
    : pqxx::broken_connection(what), _commit_xid(std::move(commit_xid)) {}

  const std::optional<std::string>& commit_xid() const { return _commit_xid; }

private:
  std::optional<std::string> _commit_xid;
};

/// Process-wide: how long a controller keeps reconnecting, measured from the first failure, while PostgreSQL refuses
/// connections because it is starting up or in crash recovery (SQLSTATE 57P03). 0 retries those like any other failure.
void set_recovery_wait(std::chrono::seconds wait);

/// Runs `unit` in a new transaction of `controller` and commits it. When the transaction is lost (transaction_lost),
/// runs `unit` again in a new transaction, which waits for the database like openTx() does, unless the lost one did
/// commit. Throws when the transaction keeps being lost, or when whether a lost commit committed cannot be determined.
void run_transaction(transaction_controller& controller, const std::function<void(transaction&)>& unit);

/// Its transactions commit synchronously: a commit that returned survives a crash of the server.
transaction_controller_ptr build_own_transaction_controller(const std::string& dbUrl, const std::string& description, appbase::application& app);
transaction_controller_ptr build_single_transaction_controller(const std::string& dbUrl, appbase::application& app);

} // namespace transaction_controllers
