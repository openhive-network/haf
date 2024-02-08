

#include <pxx.hpp>

#include <pqxx/pqxx>

#include "pqxx_impl.hpp"

namespace pqxx
{

  postgres_database_helper::postgres_database_helper(const char* url) : connection(url) 
  {

  }

  postgres_database_helper::~postgres_database_helper()
  {
  }

  pqxx::result postgres_database_helper::execute_query(const std::string& query)
  {
    pqxx::work txn(connection);
    pqxx::result query_result = txn.exec(query);
    txn.commit();
    return query_result;

    //pxx::result res(query_result);
    //return res;
  }


}

//#endif