#pragma once

// C++ connector library for PostgreSQL (http://pqxx.org/development/libpqxx/)
#include <pqxx/pqxx>

#include <memory>
#include <functional>

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

transaction_controller_ptr build_own_transaction_controller(const std::string& dbUrl, const std::string& description, appbase::application& app, bool sync_commits = false);
transaction_controller_ptr build_single_transaction_controller(const std::string& dbUrl, appbase::application& app);

} // namespace transaction_controllers

