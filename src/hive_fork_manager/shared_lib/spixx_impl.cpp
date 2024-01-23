#include "spixx_impl.hpp"

#include "spixx.hpp"

#include "psql_utils/pg_cxx.hpp"


#include <iostream>
#include <unistd.h>

namespace consensus_state_provider
{

  postgres_database_helper_spi::postgres_database_helper_spi(const char* url)  {SPI_connect();}
  postgres_database_helper_spi::~postgres_database_helper_spi(){SPI_finish();} 

  pxx::result postgres_database_helper_spi::execute_query(const std::string& query)
  {
 
    #ifndef NDEBUG
      []()
      {
        static volatile bool stop_in = true;
        using std::cout, std::endl;
        cout << "postgres_database_helper_spi::execute_query" << endl;
        cout << "pid= " << getpid() << endl;

        while(stop_in)
        {
          int a = 0;
          a=a;
        }
      }();
    #endif

    spixx::result query_result = spixx::execute_query(query);
    pxx::result res(query_result);

    return res;
  }


}


