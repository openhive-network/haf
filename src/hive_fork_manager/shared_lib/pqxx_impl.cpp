#include <pxx.hpp>

#include <pqxx/pqxx>

#include "pqxx_impl.hpp"

namespace consensus_state_provider
{

  postgres_database_helper::postgres_database_helper(const char* url) : connection(url) {}

  pxx::result postgres_database_helper::execute_query(const std::string& query)
  {
    pqxx::work txn(connection);
    pqxx::result query_result = txn.exec(query);
    txn.commit();
    //return query_result;
    return {};
  }


}