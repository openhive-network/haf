#pragma once

#include <cinttypes>
#include <string>

namespace hive::chain {
  class database;
}

namespace appbase {
  class application;
}

namespace hive::plugins::sql_serializer {

  class all_accounts_dumper{
  public:
    all_accounts_dumper(
        uint8_t number_of_threads
      , const std::string& dburl
      , hive::chain::database& chain_db
      , appbase::application& app
    );
    ~all_accounts_dumper();

  private:
    const std::string _dburl;
    appbase::application& _app;
  };

} // namespace hive::plugins::sql_serializer

