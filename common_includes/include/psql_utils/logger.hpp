#pragma once

#include "include/psql_utils/postgres_includes.hpp"

#define LOG_TO_POSTGRES( _level, _message, ... )      \
  elog( _level, "HIVE FORK EXTENSION: "  _message, ##__VA_ARGS__ )             \

#define LOG_WARNING( _message, ... )                  \
  LOG_TO_POSTGRES( WARNING, _message, ##__VA_ARGS__ ) \

#define LOG_INFO( _message, ... )                     \
  LOG_TO_POSTGRES( INFO, _message, ##__VA_ARGS__ )    \

// WARNING! log error will finish process because Postgres uses there __builtin_unreachable()
#define LOG_ERROR( _message, ... )                     \
  LOG_TO_POSTGRES( ERROR, _message, ##__VA_ARGS__ )    \

