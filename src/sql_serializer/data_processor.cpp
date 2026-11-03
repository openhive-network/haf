#include <cstdint>
#include <hive/plugins/sql_serializer/data_processor.hpp>

#include <fc/exception/exception.hpp>
#include <fc/log/logger.hpp>
#include <fc/thread/thread.hpp>
#include <appbase/application.hpp>

#include <boost/exception/diagnostic_information.hpp>

#include <exception>

#include <unistd.h>
#include <signal.h>

namespace {
  void kill_node() {
    elog( "An error occured and HAF is stopping synchronization..." );
    kill( getpid(), SIGINT );
  }
}

namespace hive { namespace plugins { namespace sql_serializer {

data_processor::data_processor( std::string description, std::string short_description, const data_processing_fn& dataProcessor, std::shared_ptr< block_num_rendezvous_trigger > api_trigger) :
  _description(std::move(description)),
  _short_description(std::move(short_description)),
  _cancel(false),
  _continue(true),
  _is_processing_data( false ),
  _total_processed_records(0),
  _randezvous_trigger( std::move( api_trigger ) )
{
  auto body = [this, dataProcessor]() -> void
  {
    dlog("Entering data processor thread: ${d}", ("d", _description));
    const std::string thread_name = "sql[" + _short_description + "]";
    fc::set_thread_name(thread_name.c_str());
    fc::thread::current().set_name(thread_name);

    try
    {
      {
        dlog("${d} data processor is connecting ...",("d", _description));
        std::unique_lock<std::mutex> lk(_mtx);
        dlog("${d} data processor connected successfully ...", ("d", _description));
        _cv.notify_one();
      }

      for(;;)
      {
        dlog("${d} data processor is waiting for DATA-READY signal...", ("d", _description));
        std::unique_lock<std::mutex> lk(_mtx);
        _cv.wait(lk, [this] {return !_queue.empty() || _continue.load() == false; });

        dlog("${d} data processor resumed by DATA-READY signal...", ("d", _description));

        /// join() drains the already queued chunks, cancel() drops them
        if(_continue.load() == false && (_queue.empty() || _cancel.load())) {
          dlog("${d} data processor _continue.load() == false", ("d", _description));
          break;
        }

        queued_batch batch = std::move(_queue.front());
        _queue.pop_front();

        lk.unlock();
        dlog("${d} data processor consumed data - notifying trigger process...", ("d", _description));
        _queue_space_cv.notify_one();

        // NOTE: We do NOT exit early on _cancel here to prevent data loss.
        // We must process the data and report to rendezvous so execute_push_block() gets called with valid data.
        // The cancel will be handled after processing completes.

        if ( !batch.report_only )
        {
          dlog("${d} data processor starts a data processing...", ("d", _description));
          dataProcessor(batch.data);
        }

        if ( _randezvous_trigger && batch.last_block_num )
        {
          dlog( "${i} commited by ${d}",("i", batch.last_block_num )("d", _description) );
          _randezvous_trigger->report_complete_thread_stage( batch.last_block_num );
        }

        notify_processing_finished_if_drained();

        dlog("${d} data processor finished processing a data chunk...", ("d", _description));
      }
    }
    catch(...)
    {
      notify_processing_finished();
      auto current_exception = std::current_exception();
      handle_exception( current_exception );
    }
    notify_processing_finished();
    dlog("Leaving data processor thread: ${d}", ("d", _description));
  };

  _future = std::async(std::launch::async, body);
}

data_processor::~data_processor()
{
  dlog("~data_processor: ${d}", ("d", _description));
}

void data_processor::trigger(data_chunk_ptr dataPtr, uint32_t last_blocknum)
{
  enqueue( { std::move(dataPtr), last_blocknum, false } );
}

void data_processor::only_report_batch_finished( uint32_t block_num )
{
  enqueue( { data_chunk_ptr(), block_num, true } );
}

void data_processor::enqueue( queued_batch&& batch )
{
  bool queued = false;

  {
    dlog("Trying to trigger data processor: ${d}...", ("d", _description));
    std::unique_lock<std::mutex> lk(_mtx);
    /// The bounded queue is the back-pressure between the serializer and this processor.
    _queue_space_cv.wait(lk, [this] { return _queue.size() < MAX_QUEUED_CHUNKS || _cancel.load() || _continue.load() == false; });

    if ( _continue.load() && _queue.size() < MAX_QUEUED_CHUNKS )
    {
      _queue.emplace_back( std::move(batch) );
      _is_processing_data = true;
      queued = true;
      dlog("Data processor: ${d} triggerred...", ("d", _description));
    }
    else
      /// Not reported to the rendezvous: the batch was not written, so the consistent block must not move past it.
      wlog("Data processor: ${d} is stopping, dropping data of batch ending at block ${b}", ("d", _description)("b", batch.last_block_num));
  }

  if ( queued )
    _cv.notify_one();

  dlog("Leaving trigger of data data processor: ${d}...", ("d", _description));
}

void data_processor::notify_processing_finished()
{
  std::lock_guard<std::mutex> lk(_data_processing_mtx);
  _is_processing_data = false;
  _data_processing_finished_cv.notify_all();
}

void data_processor::notify_processing_finished_if_drained()
{
  /// _mtx is held while clearing the flag so a concurrent trigger cannot queue a chunk in between
  std::lock_guard<std::mutex> lk(_mtx);
  if ( _queue.empty() )
    notify_processing_finished();
}

void data_processor::complete_data_processing()
{
  if(_is_processing_data == false)
    return;

  dlog("Awaiting for data processing finish in the  data processor: ${d}...", ("d", _description));
  std::unique_lock<std::mutex> lk(_data_processing_mtx);
  _data_processing_finished_cv.wait(lk, [this] { return _is_processing_data == false || _cancel.load(); });
  dlog("Data processor: ${d} finished processing data...", ("d", _description));
}

void data_processor::cancel()
{
  ilog("Attempting to cancel execution of data processor: ${d}...", ("d", _description));

  _cancel.store(true);
  join();
}

void data_processor::join()
{
  {
    dlog("Trying to resume data processor: ${d}...", ("d", _description));
    std::lock_guard<std::mutex> lk(_mtx);
    // Set _continue to false under the lock to ensure proper synchronization
    // with the condition variable wait predicate in the worker thread.
    // This prevents a race condition where the worker thread might miss the
    // shutdown signal if it checks _continue between our store and notify.
    _continue.store(false);
    dlog("Data processor: ${d} resumed...", ("d", _description));
  }
  _cv.notify_one();
  _queue_space_cv.notify_all();

  try {
    if (_future.valid())
    {
      _future.get();
    }
  } catch (...) {
    elog( "Caught unhandled exception ${diagnostic}", ("diagnostic", boost::current_exception_diagnostic_information()) );
    throw;
  }

  dlog("Data processor: ${d} finished execution...", ("d", _description));
}

void
data_processor::handle_exception( std::exception_ptr exception_ptr ) {
  try {
    if ( exception_ptr ) {
      std::unique_lock<std::mutex> lk(_mtx);
      _cancel.store(true);
      _continue.store(false);
      _cv.notify_one();
      _queue_space_cv.notify_all();
      std::rethrow_exception( exception_ptr );
    }
  }
  catch(const pqxx::sql_error& ex)
  {
    if (ex.sqlstate() == "57014") // query cancelled
    {
      wlog("Data processor ${d} detected SQL cancellation. Failing statement: `${q}', error: ${e}.", ("d", _description)("q", ex.query())("e", ex.what()));
      kill_node();
    }
    else
    {
      elog("Data processor ${d} detected SQL statement execution failure. Failing statement: `${q}'.", ("d", _description)("q", ex.query()));
      kill_node();
      throw;
    }
  }
  catch(const pqxx::failure& ex)
  {
    elog("Data processor ${d} detected SQL execution failure: ${e}", ("d", _description)("e", ex.what()));
    kill_node();
    throw;
  }
  catch(const fc::exception& ex)
  {
    elog("Data processor ${d} execution failed: ${e}", ("d", _description)("e", ex.what()));
    kill_node();
    throw;
  }
  catch(const std::exception& ex)
  {
    elog("Data processor ${d} execution failed: ${e}", ("d", _description)("e", ex.what()));
    kill_node();
    throw;
  }
  catch(...) {
    elog("Data processor ${d} execution failed: unknown exception", ("d", _description));
    kill_node();
    throw;
  }
}

}}} /// hive::plugins::sql_serializer
