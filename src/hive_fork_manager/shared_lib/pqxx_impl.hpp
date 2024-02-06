#include <pqxx/pqxx>

namespace pqxx
{

template<>
inline pxx::timestamp_wo_tz_type field::as<pxx::timestamp_wo_tz_type>() const
{
    auto a = c_str();
    return pxx::timestamp_wo_tz_type{std::string(a)};
}

template<>
inline pxx::jsonb_string field::as<pxx::jsonb_string>() const
{
    auto a = c_str();
    return pxx::jsonb_string{std::string(a)};
}

class postgres_database_helper
{
public:
  explicit postgres_database_helper(const char* url);
  ~postgres_database_helper();

  pxx::result execute_query(const std::string& query);
private:
  pqxx::connection connection;
};


} // namespace pqxx
