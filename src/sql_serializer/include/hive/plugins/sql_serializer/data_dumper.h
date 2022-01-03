#pragma once

#include <hive/plugins/sql_serializer/cached_data.h>

namespace hive::plugins::sql_serializer {
  class data_dumper {
  public:
    virtual ~data_dumper() = default;

    virtual void trigger_data_flush( cached_data_t& cached_data, int last_block_num ) = 0;
  };
} // namespace hive::plugins::sql_serializer