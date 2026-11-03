#include <cstdint>
#include "hive/plugins/sql_serializer/end_massive_sync_processor.hpp"

#include <hive/plugins/sql_serializer/queries_commit_data_processor.h>

#include <cassert>
#include <string>

using namespace std::string_literals;

namespace hive {
namespace plugins {
namespace sql_serializer {

    namespace {
      // trigger() no longer waits for the worker, so the block number must travel with the queued chunk
      struct block_number_chunk : data_processor::data_chunk
      {
        explicit block_number_chunk( uint32_t block_number ) : _block_number( block_number ) {}
        const uint32_t _block_number;
      };
    }

    end_massive_sync_processor::end_massive_sync_processor( std::string psqlUrl, appbase::application& app )
    {
      auto commiting_function = [](const data_processor::data_chunk_ptr& dataPtr, transaction_controllers::transaction& tx) -> data_processor::data_processing_status {
        const auto block_number = static_cast< const block_number_chunk& >( *dataPtr )._block_number;
        tx.exec( "SELECT hive.end_massive_sync("s + std::to_string( block_number ) + ")"s );

        return data_processor::data_processing_status();
      };

      _data_processor = std::make_unique< queries_commit_data_processor >(psqlUrl, "commiting hive.end_massive_sync", "endmassive", commiting_function, nullptr, app );
    }

    void
    end_massive_sync_processor::trigger_block_number( uint32_t last_dumped_block ) {
      // Serializes concurrent callers so their batches are queued in the order they arrive.
      // Contention is extremely rare — it requires two conditions simultaneously: (1) a
      // writer has no data to dump for its batch (e.g. few operations split among many
      // threads in early blockchain), causing the main thread to report via
      // only_report_batch_finished() which bypasses the normal trigger/pickup
      // synchronization, AND (2) the OS thread scheduler delays the worker that is inside
      // trigger_block_number() for batch N long enough for the main thread to complete
      // batch N+1 and fire its rendezvous.
      std::lock_guard<std::mutex> guard(_trigger_mtx);
      _data_processor->trigger( std::make_unique< block_number_chunk >( last_dumped_block ), 0 );
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
