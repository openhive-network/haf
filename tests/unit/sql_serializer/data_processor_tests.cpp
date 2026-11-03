#include <boost/test/unit_test.hpp>

#include <hive/plugins/sql_serializer/data_processor.hpp>
#include <hive/plugins/sql_serializer/block_num_rendezvous_trigger.hpp>

#include <chrono>
#include <cstdint>
#include <deque>
#include <future>
#include <memory>
#include <mutex>
#include <vector>

using hive::plugins::sql_serializer::data_processor;
using hive::plugins::sql_serializer::block_num_rendezvous_trigger;

namespace {
  using namespace std::chrono_literals;

  struct numbered_chunk : data_processor::data_chunk
  {
    explicit numbered_chunk( uint32_t number ) : _number( number ) {}
    const uint32_t _number;
  };

  /// A processor whose processing thread stays inside the first chunk until release() is called.
  struct gated_processor
  {
    gated_processor()
      : _released( _release.get_future().share() )
      , _rendezvous( std::make_shared< block_num_rendezvous_trigger >( 1, [this]( uint32_t block_num ) {
          std::lock_guard< std::mutex > lk( _mtx );
          _reported.push_back( block_num );
        } ) )
      , _processor( "test data processor", "test", [this]( const data_processor::data_chunk_ptr& chunk ) {
          _first_chunk_started.set_value_once();
          _released.wait();
          std::lock_guard< std::mutex > lk( _mtx );
          _processed.push_back( static_cast< const numbered_chunk& >( *chunk )._number );
          return data_processor::data_processing_status();
        }, _rendezvous )
    {}

    /// Lets a failed check end the test instead of leaving the processing or a trigger thread blocked.
    ~gated_processor()
    {
      release();
      _processor.join();
    }

    std::future< void >& trigger_async( uint32_t number )
    {
      _triggers.push_back( std::async( std::launch::async, [this, number] {
        _processor.trigger( std::make_unique< numbered_chunk >( number ), number );
      } ) );
      return _triggers.back();
    }

    void wait_until_first_chunk_is_processing()
    {
      BOOST_REQUIRE( _first_chunk_started.future.wait_for( 10s ) == std::future_status::ready );
    }

    void release() { std::call_once( _release_flag, [this] { _release.set_value(); } ); }

    std::vector< uint32_t > processed() { std::lock_guard< std::mutex > lk( _mtx ); return _processed; }
    std::vector< uint32_t > reported() { std::lock_guard< std::mutex > lk( _mtx ); return _reported; }

    struct once_signal
    {
      std::promise< void > promise;
      std::future< void > future = promise.get_future();
      std::once_flag flag;
      void set_value_once() { std::call_once( flag, [this] { promise.set_value(); } ); }
    };

    std::mutex _mtx;
    std::vector< uint32_t > _processed;
    std::vector< uint32_t > _reported;
    once_signal _first_chunk_started;
    std::promise< void > _release;
    std::once_flag _release_flag;
    std::shared_future< void > _released;
    std::shared_ptr< block_num_rendezvous_trigger > _rendezvous;
    data_processor _processor;
    std::deque< std::future< void > > _triggers;
  };
}

BOOST_AUTO_TEST_SUITE( data_processor_tests )

BOOST_AUTO_TEST_CASE( trigger_returns_while_previous_batches_are_still_processed )
{
  gated_processor p;

  BOOST_REQUIRE( p.trigger_async( 1 ).wait_for( 10s ) == std::future_status::ready );
  p.wait_until_first_chunk_is_processing();

  BOOST_CHECK( p.trigger_async( 2 ).wait_for( 10s ) == std::future_status::ready );
  BOOST_CHECK( p.trigger_async( 3 ).wait_for( 10s ) == std::future_status::ready );
  BOOST_CHECK( p.processed().empty() );

  p.release();
  p._processor.complete_data_processing();

  const std::vector< uint32_t > expected{ 1, 2, 3 };
  const auto processed = p.processed();
  const auto reported = p.reported();
  BOOST_CHECK_EQUAL_COLLECTIONS( processed.begin(), processed.end(), expected.begin(), expected.end() );
  BOOST_CHECK_EQUAL_COLLECTIONS( reported.begin(), reported.end(), expected.begin(), expected.end() );
}

BOOST_AUTO_TEST_CASE( trigger_waits_when_queue_is_full )
{
  gated_processor p;

  BOOST_REQUIRE( p.trigger_async( 1 ).wait_for( 10s ) == std::future_status::ready );
  p.wait_until_first_chunk_is_processing();
  BOOST_REQUIRE( p.trigger_async( 2 ).wait_for( 10s ) == std::future_status::ready );
  BOOST_REQUIRE( p.trigger_async( 3 ).wait_for( 10s ) == std::future_status::ready );

  auto& fourth = p.trigger_async( 4 );
  BOOST_CHECK( fourth.wait_for( 200ms ) == std::future_status::timeout );

  p.release();
  BOOST_CHECK( fourth.wait_for( 10s ) == std::future_status::ready );
  p._processor.complete_data_processing();

  const std::vector< uint32_t > expected{ 1, 2, 3, 4 };
  const auto processed = p.processed();
  BOOST_CHECK_EQUAL_COLLECTIONS( processed.begin(), processed.end(), expected.begin(), expected.end() );
}

BOOST_AUTO_TEST_CASE( join_processes_already_queued_chunks )
{
  gated_processor p;

  BOOST_REQUIRE( p.trigger_async( 1 ).wait_for( 10s ) == std::future_status::ready );
  p.wait_until_first_chunk_is_processing();
  BOOST_REQUIRE( p.trigger_async( 2 ).wait_for( 10s ) == std::future_status::ready );
  BOOST_REQUIRE( p.trigger_async( 3 ).wait_for( 10s ) == std::future_status::ready );

  auto joined = std::async( std::launch::async, [&p] { p._processor.join(); } );
  BOOST_CHECK( joined.wait_for( 200ms ) == std::future_status::timeout );

  p.release();
  BOOST_REQUIRE( joined.wait_for( 10s ) == std::future_status::ready );

  const std::vector< uint32_t > expected{ 1, 2, 3 };
  const auto reported = p.reported();
  BOOST_CHECK_EQUAL_COLLECTIONS( reported.begin(), reported.end(), expected.begin(), expected.end() );
}

BOOST_AUTO_TEST_SUITE_END()
