#include "hive/plugins/sql_serializer/end_massive_sync_processor.hpp"

#include <hive/plugins/sql_serializer/queries_commit_data_processor.h>

#include <cassert>
#include <string>

using namespace std::string_literals;

namespace hive {
namespace plugins {
namespace sql_serializer {

    end_massive_sync_processor::end_massive_sync_processor( std::string psqlUrl, appbase::application& app )
    {
      auto commiting_function = [this](const data_processor::data_chunk_ptr&, transaction_controllers::transaction& tx) -> data_processor::data_processing_status {
        tx.exec( "SELECT hive.end_massive_sync("s + std::to_string( _block_number ) + ")"s );

        return data_processor::data_processing_status();
      };

      _data_processor = std::make_unique< queries_commit_data_processor >(psqlUrl, "commiting hive.end_massive_sync", "endmassive", commiting_function, nullptr, app );
    }

    void
    end_massive_sync_processor::trigger_block_number( uint32_t last_dumped_block ) {
      // Serializes concurrent callers. Contention is extremely rare — it requires two
      // conditions simultaneously: (1) a writer has no data to dump for its batch (e.g.
      // few operations split among many threads in early blockchain), causing the main
      // thread to report via only_report_batch_finished() which bypasses the normal
      // trigger/pickup synchronization, AND (2) the OS thread scheduler delays the worker
      // that is inside trigger_block_number() for batch N long enough for the main thread
      // to complete batch N+1 and fire its rendezvous. Only then do two concurrent
      // trigger() calls hit the same data_processor — one of which would hang forever.
      std::lock_guard<std::mutex> guard(_trigger_mtx);
      _block_number = last_dumped_block;
      _data_processor->trigger( nullptr, 0 );
    }

    void
    end_massive_sync_processor::complete_data_processing() {
      _data_processor->complete_data_processing();
    }

    void
    end_massive_sync_processor::join() {
      assert( _data_processor );
      _data_processor->join();
    }

    void
    end_massive_sync_processor::cancel() {
      assert( _data_processor );
      _data_processor->cancel();
    }
}}} // namespace hive { namespace plugins { namespace sql_serializer {
