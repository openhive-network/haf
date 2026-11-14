#include <boost/test/unit_test.hpp>

#include <hive/plugins/sql_serializer/contexts_compactor.hpp>

#include <chrono>
#include <stdexcept>
#include <thread>

using hive::plugins::sql_serializer::contexts_compactor;

namespace {
  using namespace std::chrono_literals;

  // libpq fails at once: the socket directory does not exist
  const std::string UNREACHABLE_DB = "host=/nonexistent-haf-socket-dir dbname=haf_block_log";
}

BOOST_AUTO_TEST_SUITE( contexts_compactor_tests )

BOOST_AUTO_TEST_CASE( zero_gate_timeout_is_refused )
{
  contexts_compactor::settings s;
  s.gate_timeout = 0ms;
  BOOST_CHECK_THROW( contexts_compactor( UNREACHABLE_DB, s ), std::invalid_argument );
}

BOOST_AUTO_TEST_CASE( zero_lock_timeout_is_refused )
{
  contexts_compactor::settings s;
  s.lock_timeout = 0ms;
  BOOST_CHECK_THROW( contexts_compactor( UNREACHABLE_DB, s ), std::invalid_argument );
}

BOOST_AUTO_TEST_CASE( zero_threshold_disables_compaction )
{
  contexts_compactor::settings s;
  BOOST_CHECK( s.is_enabled() );
  s.threshold_pages = 0;
  BOOST_CHECK( !s.is_enabled() );
  BOOST_CHECK_NO_THROW( contexts_compactor( UNREACHABLE_DB, s ).on_block( true ) );
}

BOOST_AUTO_TEST_CASE( failing_runs_are_retried_and_shutdown_is_prompt )
{
  const auto started_at = std::chrono::steady_clock::now();
  {
    contexts_compactor compactor( UNREACHABLE_DB, contexts_compactor::settings{} );
    for ( int block = 0; block < 3; ++block )
    {
      compactor.on_block( true );
      std::this_thread::sleep_for( 50ms );
    }
  }
  BOOST_CHECK( std::chrono::steady_clock::now() - started_at < 2s );
}

BOOST_AUTO_TEST_SUITE_END()
