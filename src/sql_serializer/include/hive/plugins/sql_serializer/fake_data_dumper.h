#pragma once

#include <hive/plugins/sql_serializer/data_dumper.h>

namespace hive::plugins::sql_serializer {
  class fake_data_dumper : public data_dumper {
  public:
    void trigger_data_flush( cached_data_t& cached_data, int last_block_num ) override {};
  };
} // namespace hive::plugins::sql_serializer