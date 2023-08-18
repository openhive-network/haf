#pragma once

#include "psql_utils/postgres_includes.hpp"

#define LOG_TO_POSTGRES( _level, _message, ... )      \
  ereport( _level, errmsg("HIVE EXTENSION: "  _message, ##__VA_ARGS__) )             \

#define LOG_WARNING( _message, ... )                  \
  LOG_TO_POSTGRES( WARNING, _message, ##__VA_ARGS__ ) \

#define LOG_INFO( _message, ... )                     \
  LOG_TO_POSTGRES( INFO, _message, ##__VA_ARGS__ )    \

// WARNING! log error will finish process because Postgres uses there __builtin_unreachable()
#define LOG_ERROR( _message, ... )                     \
  LOG_TO_POSTGRES( ERROR, _message, ##__VA_ARGS__ )    \

#define LOG_DEBUG( _message, ... )                     \
  LOG_TO_POSTGRES( DEBUG1, _message, ##__VA_ARGS__ )   \

