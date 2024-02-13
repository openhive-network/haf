#pragma once 

#include "spixx.hpp"

namespace spixx
{

class postgres_database_helper
{
public:
  explicit postgres_database_helper(const char* url);
  ~postgres_database_helper();

  struct connect_guard
  {
    connect_guard();
    ~connect_guard();
  };


  spixx::result execute_query(const std::string& query);
private:
};


}
