#include "pxx.hpp"

namespace consensus_state_provider
{

class postgres_database_helper_spi
{
public:
  explicit postgres_database_helper_spi(const char* url);
  ~postgres_database_helper_spi();


  pxx::result execute_query(const std::string& query);
private:
};


} // namespace consensus_state_provider
