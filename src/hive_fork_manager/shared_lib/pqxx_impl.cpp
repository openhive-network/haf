#include <pxx.hpp>

#include <pqxx/pqxx>

namespace consensus_state_provider
{

class postgres_database_helper
{
public:
  explicit postgres_database_helper(const char* url) : connection(url) {}

  pxx::result execute_query(const std::string& query)
  {
    pqxx::work txn(connection);
    pqxx::result query_result = txn.exec(query);
    txn.commit();
    //return query_result;
    return {};
  }

  
private:
  pqxx::connection connection;
};


}