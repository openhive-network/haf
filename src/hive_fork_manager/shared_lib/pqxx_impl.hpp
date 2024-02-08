#pragma once 
#include <pqxx/pqxx>
#include "pxx_new_types.hpp"

namespace pqxx
{

template<>
inline pxx_new_types::timestamp_wo_tz_type field::as<pxx_new_types::timestamp_wo_tz_type>() const
{
    auto a = c_str();
    return pxx_new_types::timestamp_wo_tz_type{std::string(a)};
}

template<>
inline pxx_new_types::jsonb_string field::as<pxx_new_types::jsonb_string>() const
{
    auto a = c_str();
    return pxx_new_types::jsonb_string{std::string(a)};
}

class postgres_database_helper
{
public:
  explicit postgres_database_helper(const char* url);
  ~postgres_database_helper();

  pqxx::result execute_query(const std::string& query);
private:
  pqxx::connection connection;
};


} // namespace pqxx
