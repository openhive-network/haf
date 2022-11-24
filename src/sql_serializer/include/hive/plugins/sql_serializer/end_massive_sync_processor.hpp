#pragma once

#include <hive/plugins/sql_serializer/synchronicity_data.hpp>

#include <memory>

namespace hive::plugins::sql_serializer {
  class queries_commit_data_processor;

  class end_massive_sync_processor
  {
  public:
    end_massive_sync_processor( std::string psqlUrl, synchronicity_data::synchronicity_data_ptr synchronicity );
    end_massive_sync_processor( end_massive_sync_processor& ) = delete;
    end_massive_sync_processor( end_massive_sync_processor&& ) = delete;
    end_massive_sync_processor& operator=( end_massive_sync_processor& ) = delete;
    end_massive_sync_processor& operator=( end_massive_sync_processor&& ) = delete;
    ~end_massive_sync_processor() = default;

    void trigger_block_number( uint32_t last_dumbed_block );

    void complete_data_processing();
    void join();
  private:
    std::unique_ptr< queries_commit_data_processor > _data_processor;
    uint32_t _block_number;
  };

} // namespace hive::plugins { namespace sql_serializer {
