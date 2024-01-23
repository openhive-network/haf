#include <pqxx/pqxx>

namespace pqxx
{
    template<>
    inline pxx::timestamp_wo_tz_type field::as<pxx::timestamp_wo_tz_type>() const
    {
        auto a = c_str();
        return pxx::timestamp_wo_tz_type{std::string(a)};
    }
}

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
