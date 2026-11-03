#pragma once

#include <cstdint>
#include <transactions_controller/transaction_controllers.hpp>
#include <hive/plugins/sql_serializer/block_num_rendezvous_trigger.hpp>

#include <fc/optional.hpp>

#include <atomic>
#include <condition_variable>
#include <cstddef>
#include <deque>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <future>
#include <utility>


namespace hive { namespace plugins { namespace sql_serializer {

class data_processor 
{
public:
  class data_chunk
  {
  public:
    virtual ~data_chunk() = default;
  };

  using transaction_ptr =  transaction_controllers::transaction_controller::transaction_ptr;

  typedef std::unique_ptr<data_chunk> data_chunk_ptr;

  /// pairs number of produced chunks and write status
  typedef std::pair<size_t, bool> data_processing_status;
  typedef std::function<data_processing_status(const data_chunk_ptr& dataPtr)> data_processing_fn;

  data_processor( std::string description, std::string short_description, const data_processing_fn& dataProcessor, std::shared_ptr< block_num_rendezvous_trigger > api_trigger );
  ~data_processor();

  data_processor(data_processor&&) = delete;
  data_processor& operator=(data_processor&&) = delete;
  data_processor(const data_processor&) = delete;
  data_processor& operator=(const data_processor&) = delete;

  /// Queues a chunk for the processing thread and returns without waiting for it to be processed.
  /// Blocks only while MAX_QUEUED_CHUNKS chunks are already waiting behind the one being processed.
  void trigger(data_chunk_ptr dataPtr, uint32_t last_blocknum);
  //where there the chunk is empty, only confirms that the bunch of blocks was processed by the processor
  void only_report_batch_finished( uint32_t _block_num );
  /// Holds execution of calling thread until every triggered chunk has been processed.
  void complete_data_processing();
  void cancel();
  void join();
private:
  static constexpr std::size_t MAX_QUEUED_CHUNKS = 2;

  void handle_exception( std::exception_ptr exception_ptr );
  void notify_processing_finished();
  void notify_processing_finished_if_drained();

private:
  std::string _description;
  std::string _short_description;
  std::atomic_bool _cancel;
  std::atomic_bool _continue;
  std::atomic_bool _is_processing_data;

  std::future<void> _future;
  std::mutex _mtx;
  std::mutex _data_processing_mtx;
  std::condition_variable _cv;
  std::condition_variable _queue_space_cv;
  std::condition_variable _data_processing_finished_cv;
  /// chunks waiting for the processing thread, paired with the last block number of their batch
  std::deque< std::pair< data_chunk_ptr, uint32_t > > _queue;

  size_t _total_processed_records;

  std::shared_ptr< block_num_rendezvous_trigger > _randezvous_trigger;
};

}}} /// hive::plugins::sql_serializer

