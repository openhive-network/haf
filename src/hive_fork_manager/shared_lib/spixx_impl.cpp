#include "spixx_impl.hpp"

#include "spixx.hpp"

#include "psql_utils/pg_cxx.hpp"


#include <iostream>
using std::cout, std::endl;
#include <unistd.h>

namespace consensus_state_provider
{

  postgres_database_helper_spi::postgres_database_helper_spi(const char* url)  
  {

    #ifndef NDEBUG
      []()
      {
        static volatile bool stop_in = true;
        using std::cout, std::endl;
        cout << "mtlk 006 csp_session_type::csp_session_type" << endl;
        cout << "pid= " << getpid() << endl;

        while(stop_in)
        {
          int a = 0;
          a=a;
        }
        int a = 0;
        a=a;
      }();
    #endif

  }

  postgres_database_helper_spi::~postgres_database_helper_spi()
  {
  } 

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

  postgres_database_helper_spi::spi_connect_guard::spi_connect_guard()
  {
    if(SPI_connect() == SPI_OK_CONNECT)
    {
      //cout << "SPI_OK_CONNECT" << endl;
    }
    else
    {
      cout << "SPI_ERROR_CONNECT" << endl;
    }
  }

  postgres_database_helper_spi::spi_connect_guard::~spi_connect_guard()
  {
    SPI_finish();
  }

}


