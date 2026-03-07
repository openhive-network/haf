#pragma once

#include <string>

namespace hive::plugins::sql_serializer {

/// Appends application_name to a PostgreSQL connection URL (URI or key-value format).
/// If the URL already contains an application_name, returns it unchanged.
inline std::string db_url_with_app(const std::string& db_url, const char* app_name)
{
  const std::string app_kv = std::string("application_name=") + app_name;
  if (db_url.find("application_name=") != std::string::npos)
    return db_url;
  const bool is_uri = db_url.rfind("postgres://", 0) == 0 || db_url.rfind("postgresql://", 0) == 0;
  if (is_uri)
  {
    const char sep = (db_url.find('?') == std::string::npos) ? '?' : '&';
    return db_url + sep + app_kv;
  }
  return db_url + " " + app_kv;
}

} // namespace hive::plugins::sql_serializer
