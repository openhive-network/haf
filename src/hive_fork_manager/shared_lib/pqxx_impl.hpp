#include <pqxx/pqxx>

namespace consensus_state_provider
{

class postgres_database_helper
{
public:
  explicit postgres_database_helper(const char* url);

  pxx::result execute_query(const std::string& query);
private:
  pqxx::connection connection;
};


} // namespace consensus_state_provider
