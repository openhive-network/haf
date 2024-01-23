#include <pxx.hpp>

#include <pqxx/pqxx>

#include "pqxx_impl.hpp"

#include <iostream>
#include <unistd.h>


namespace consensus_state_provider
{

  postgres_database_helper::postgres_database_helper(const char* url) : connection(url) {}

  pxx::result postgres_database_helper::execute_query(const std::string& query)
  {
    pqxx::work txn(connection);
    pqxx::result query_result = txn.exec(query);
    txn.commit();

    #ifndef NDEBUG
      []()
      {
        static volatile bool stop_in = true;
        using std::cout, std::endl;
        cout << "postgres_database_helper::execute_query" << endl;
        cout << "pid= " << getpid() << endl;

        while(stop_in)
        {
          int a = 0;
          a=a;
        }
      }();
    #endif      


    pxx::result res(query_result);
    return res;
  }


}