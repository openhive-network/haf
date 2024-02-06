#pragma once 

#include "pxx.hpp"

namespace spixx
{

class postgres_database_helper_spi
{
public:
  explicit postgres_database_helper_spi(const char* url);
  ~postgres_database_helper_spi();

  struct spi_connect_guard
  {
    spi_connect_guard();
    ~spi_connect_guard();
  };


  pxx::result execute_query(const std::string& query);
private:
};


}
