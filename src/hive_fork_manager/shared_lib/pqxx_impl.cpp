
#ifdef USE_PQXX

#include <pxx.hpp>

#include <pqxx/pqxx>

#include "pqxx_impl.hpp"

#include <iostream>
#include <unistd.h>


namespace consensus_state_provider
{

  postgres_database_helper::postgres_database_helper(const char* url) : connection(url) 
  {

  }

  postgres_database_helper::~postgres_database_helper()
  {
  }

  pxx::result postgres_database_helper::execute_query(const std::string& query)
  {
    pqxx::work txn(connection);
    pqxx::result query_result = txn.exec(query);
    txn.commit();



    pxx::result res(query_result);
    return res;
  }


}

#endif