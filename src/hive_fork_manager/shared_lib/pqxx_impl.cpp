
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
    std::cout << "mtlk  014 postgres_database_helper" << std::endl;

  }

  postgres_database_helper::~postgres_database_helper()
  {
    std::cout << "mtlk  015 ~postgres_database_helper" << std::endl;
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