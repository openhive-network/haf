#include <hive/plugins/sql_serializer/contexts_compactor.hpp>

#include <algorithm>
#include <stdexcept>

#include <fc/log/logger.hpp>
#include <fc/time.hpp>

namespace hive { namespace plugins { namespace sql_serializer {

namespace {

const std::string LOCK_NOT_AVAILABLE = "55P03";

int64_t milliseconds_since( const fc::time_point& start )
{
  return ( fc::time_point::now() - start ).count() / 1000;
}

int64_t heap_pages( pqxx::nontransaction& tx )
{
  return tx.exec( "SELECT hive.contexts_heap_pages() AS pages" )[ 0 ][ "pages" ].as< int64_t >();
}

const contexts_compactor::settings& validated( const contexts_compactor::settings& s )
{
  // PostgreSQL reads a lock_timeout of 0 as "no timeout", which would let a compaction hold every application back.
  if ( s.gate_timeout.count() <= 0 )
    throw std::invalid_argument( "psql-contexts-compaction-gate-timeout must be greater than 0 ms" );
  if ( s.lock_timeout.count() <= 0 )
    throw std::invalid_argument( "psql-contexts-compaction-lock-timeout must be greater than 0 ms; set psql-contexts-compaction-threshold to 0 to disable the compaction" );
  if ( s.gate_poll_interval.count() <= 0 )
    throw std::invalid_argument( "the poll interval of the hafd.contexts compaction gate must be greater than 0 ms" );
  return s;
}

} // namespace

contexts_compactor::contexts_compactor( std::string db_url, settings compaction_settings )
  : _db_url( std::move( db_url ) )
  , _settings( validated( compaction_settings ) )
  , _thread( [this]{ run(); } )
{
  if ( !_settings.is_enabled() )
    ilog( "Compaction of hafd.contexts is disabled (psql-contexts-compaction-threshold is 0)" );
}

contexts_compactor::~contexts_compactor()
{
  {
    std::lock_guard< std::mutex > lock( _mutex );
    _stopping = true;
    if ( _conn )
    {
      try
      {
        _conn->cancel_query();
      }
      catch ( const std::exception& e )
      {
        wlog( "Could not cancel the query of the hafd.contexts compaction in progress: ${e}; shutdown waits for it", ( "e", e.what() ) );
      }
    }
  }
  _cv.notify_one();
  _thread.join();
}

void contexts_compactor::on_block( bool is_live )
{
  if ( !is_live || !_settings.is_enabled() )
    return;

  {
    std::lock_guard< std::mutex > lock( _mutex );
    _requested = true;
  }
  _cv.notify_one();
}

void contexts_compactor::run()
{
  for ( ;; )
  {
    {
      std::unique_lock< std::mutex > lock( _mutex );
      _cv.wait( lock, [this]{ return _requested || _stopping; } );
      if ( _stopping )
        return;
    }

    const char* error = nullptr;
    std::string what;
    try
    {
      connect_if_needed();
      compact_if_needed( *_conn );
    }
    catch ( const std::exception& e )
    {
      what = e.what();
      error = what.c_str();
    }
    catch ( ... )
    {
      error = "unknown exception";
    }

    if ( error )
    {
      // Dropping the connection also releases the gate, a session-level advisory lock.
      drop_connection();
      if ( !is_stopping() )
        elog( "Compaction of hafd.contexts failed: ${e}; it will be retried at a later block", ( "e", error ) );
    }

    {
      // Blocks applied during this run do not start the next one: it waits for a new block.
      std::lock_guard< std::mutex > lock( _mutex );
      _requested = false;
    }
  }
}

void contexts_compactor::connect_if_needed()
{
  if ( _conn )
    return;
  auto conn = std::make_unique< pqxx::connection >( _db_url );
  std::lock_guard< std::mutex > lock( _mutex );
  _conn = std::move( conn );
}

void contexts_compactor::drop_connection()
{
  std::unique_ptr< pqxx::connection > conn;
  {
    std::lock_guard< std::mutex > lock( _mutex );
    conn = std::move( _conn );
  }
}

bool contexts_compactor::is_stopping()
{
  std::lock_guard< std::mutex > lock( _mutex );
  return _stopping;
}

void contexts_compactor::compact_if_needed( pqxx::connection& conn )
{
  pqxx::nontransaction tx( conn );

  // A table the last compaction could not bring under the threshold is not rewritten again at every block.
  const int64_t threshold = std::max< int64_t >( _settings.threshold_pages, _pages_after_last_compaction );
  pqxx::result state = tx.exec( "SELECT hive.is_contexts_compaction_needed( " + std::to_string( threshold ) + " ) AS needed" );
  if ( !state[ 0 ][ "needed" ].as< bool >() )
    return;
  const int64_t pages_before = heap_pages( tx );

  const auto gate_start = fc::time_point::now();
  if ( !enter_gate( tx ) )
  {
    if ( !is_stopping() )
      skipped( "applications' iterations kept the gate", pages_before, milliseconds_since( gate_start ) );
    return;
  }
  const int64_t gate_wait = milliseconds_since( gate_start );

  bool compacted = false;
  int64_t rewrite_duration = 0;
  if ( !is_stopping() )
  {
    tx.exec( "SET lock_timeout = " + std::to_string( _settings.lock_timeout.count() ) );
    const auto rewrite_start = fc::time_point::now();
    try
    {
      tx.exec( "VACUUM FULL hafd.contexts" );
      compacted = true;
    }
    catch ( const pqxx::sql_error& e )
    {
      if ( e.sqlstate() != LOCK_NOT_AVAILABLE )
        throw;
    }
    rewrite_duration = milliseconds_since( rewrite_start );
    tx.exec( "RESET lock_timeout" );
  }
  tx.exec( "SELECT pg_advisory_unlock( hive.contexts_compaction_gate_key() )" );

  if ( is_stopping() )
    return;
  if ( !compacted )
  {
    skipped( "another session held a lock on hafd.contexts", pages_before, gate_wait );
    return;
  }

  const int64_t pages_after = heap_pages( tx );
  ilog( "Compacted hafd.contexts from ${before} to ${after} pages: gate wait ${gate} ms, rewrite ${rewrite} ms, after ${skips} consecutive skips",
        ( "before", pages_before )( "after", pages_after )( "gate", gate_wait )( "rewrite", rewrite_duration )( "skips", _consecutive_skips ) );
  if ( pages_after > _settings.threshold_pages )
    wlog( "hafd.contexts still has ${after} pages after its compaction, more than the threshold of ${t}; it is compacted again once it grows past ${after}",
          ( "after", pages_after )( "t", _settings.threshold_pages ) );
  _pages_after_last_compaction = pages_after;
  _consecutive_skips = 0;
}

// Never queues for the gate: a waiting exclusive request would hold back every application's
// iteration that asks for the gate after it, however long the iterations already holding it run.
bool contexts_compactor::enter_gate( pqxx::nontransaction& tx )
{
  const auto deadline = std::chrono::steady_clock::now() + _settings.gate_timeout;
  for ( ;; )
  {
    if ( tx.exec( "SELECT pg_try_advisory_lock( hive.contexts_compaction_gate_key() ) AS entered" )[ 0 ][ "entered" ].as< bool >() )
      return true;

    const auto now = std::chrono::steady_clock::now();
    if ( now >= deadline )
      return false;
    std::unique_lock< std::mutex > lock( _mutex );
    if ( _cv.wait_until( lock, std::min( now + _settings.gate_poll_interval, deadline ), [this]{ return _stopping; } ) )
      return false;
  }
}

void contexts_compactor::skipped( const char* reason, int64_t pages, int64_t gate_wait )
{
  ++_consecutive_skips;
  if ( _consecutive_skips >= _settings.skips_before_warning )
    wlog( "Compaction of hafd.contexts (${pages} pages) skipped ${n} times in a row: ${reason} (gate wait ${gate} ms); it will be retried at a later block",
          ( "pages", pages )( "n", _consecutive_skips )( "reason", reason )( "gate", gate_wait ) );
  else
    ilog( "Compaction of hafd.contexts (${pages} pages) skipped, ${n} times in a row: ${reason} (gate wait ${gate} ms); it will be retried at a later block",
          ( "pages", pages )( "n", _consecutive_skips )( "reason", reason )( "gate", gate_wait ) );
}

} } } // namespace hive::plugins::sql_serializer
