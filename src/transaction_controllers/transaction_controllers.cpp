#include "include/transactions_controller/transaction_controllers.hpp"

#include <appbase/application.hpp>

#include <fc/exception/exception.hpp>

#include <atomic>
#include <chrono>
#include <mutex>
#include <string>
#include <thread>

namespace transaction_controllers {

namespace {

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
      FC_ASSERT(_owner->_opened_tx == nullptr);
      _owner->_opened_tx = this;

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
    void rollback() override;

  private:
    template <typename Executor>
    auto with_retry(Executor ex) -> decltype(ex())
    {
      unsigned int retry = 0;
      const unsigned int MAX_RETRY_COUNT = 100;

      pqxx::broken_connection copy;

      do
      {
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
        catch(const pqxx::broken_connection& ex)
        {
          _opened_tx.reset();
          if(_owner->_opened_connection != nullptr)
          {
            _owner->_opened_connection->disconnect();
            _owner->_opened_connection.release();
          }
          else
          {
            dlog("Not closing connection, because it was not set");
          }

          wlog("Transaction controller: `${d}' lost connection to database: `${url}'. Retrying # ${r}...", ("d", _owner->_description)("url", _owner->_dbUrl)("r", retry));
          ++retry;

          copy = ex;

          /// Give a chance to restart server or somehow "repair" it
          using namespace std::chrono_literals;
          std::this_thread::sleep_for(500ms);
        }
      } while(retry < MAX_RETRY_COUNT && !_owner->get_app().is_interrupt_request() )
      ;

      elog("Transaction controller: `${d}' permanently lost connection to database: `${url}'. Exiting.", ("d", _owner->_description)("url", _owner->_dbUrl));

      throw copy;
    }


    void do_reconnect()
    {
      try
      {
        _opened_tx.reset();
        if(_owner->_opened_connection != nullptr)
        {
          _owner->_opened_connection->disconnect();
          _owner->_opened_connection.release();
        }
      }
      catch(const pqxx::pqxx_exception& ex)
      {
        ilog("Ignoring a pqxx exception during an implicit disconnect forced by reconnect request: ${e}", ("e", ex.base().what()));
      }

      dlog("Trying to connect to database: `${url}'...", ("url", _owner->_dbUrl));
      _owner->_opened_connection = std::make_unique<pqxx::connection>(_owner->_dbUrl);
      dlog("Connected to database: `${url}'.", ("url", _owner->_dbUrl));
      //use async commits to speed up writes
      pqxx::nontransaction work(*_owner->_opened_connection);
      work.exec("SET synchronous_commit = OFF;");
    }

    void finalize_transaction()
    {
      if(_owner != nullptr)
      {
        FC_ASSERT(_owner->_opened_tx == this);
        _owner->_opened_tx = nullptr;
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
  };

private:
  const std::string _dbUrl;
  const std::string _description;
  appbase::application& _theApp;

  std::unique_ptr<pqxx::connection> _opened_connection;
  own_transaction* _opened_tx = nullptr;

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
    _opened_tx->commit();
    _opened_tx.reset();
  }

  finalize_transaction();
}

pqxx::result own_tx_controller::own_transaction::exec(const std::string& query)
{
  return with_retry([this, &query]() -> pqxx::result
    {
      FC_ASSERT(_opened_tx, "No transaction opened");

      return _opened_tx->exec(query);
    }
  );
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
    if(_opened_tx != nullptr) {
      _opened_tx->rollback();
    }

    _opened_connection->disconnect();
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


} // namespace

transaction_controller_ptr build_own_transaction_controller(const std::string& dbUrl, const std::string& description, appbase::application& app)
{
  return std::make_shared<own_tx_controller>(dbUrl, description, app);
}

transaction_controller_ptr build_single_transaction_controller(const std::string& dbUrl, appbase::application& app)
{
  return std::make_shared<single_transaction_controller>(dbUrl, app);
}

} // namespace transaction_controllers
