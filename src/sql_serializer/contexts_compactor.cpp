#include <hive/plugins/sql_serializer/contexts_compactor.hpp>

#include <algorithm>
#include <memory>

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

} // namespace

contexts_compactor::contexts_compactor( std::string db_url, settings compaction_settings )
  : _db_url( std::move( db_url ) )
  , _settings( compaction_settings )
  , _thread( [this]{ run(); } )
{
}

contexts_compactor::~contexts_compactor()
{
  {
    std::lock_guard< std::mutex > lock( _mutex );
    _stopping = true;
  }
  _requested_cv.notify_one();
  _thread.join();
}

void contexts_compactor::on_block( bool is_live )
{
  if ( !is_live )
    return;

  {
    std::lock_guard< std::mutex > lock( _mutex );
    _requested = true;
  }
  _requested_cv.notify_one();
}

void contexts_compactor::run()
{
  std::unique_ptr< pqxx::connection > conn;
  for ( ;; )
  {
    {
      std::unique_lock< std::mutex > lock( _mutex );
      _requested_cv.wait( lock, [this]{ return _requested || _stopping; } );
      if ( _stopping )
        return;
      _requested = false;
    }

    try
    {
      if ( !conn )
        conn = std::make_unique< pqxx::connection >( _db_url );
      compact_if_needed( *conn );
    }
    catch ( const pqxx::failure& e )
    {
      // Dropping the connection also releases the gate, a session-level advisory lock.
      elog( "Compaction of hafd.contexts failed: ${e}; it will be retried at a later block", ( "e", e.what() ) );
      conn.reset();
    }
  }
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
  tx.exec( "SET lock_timeout = " + std::to_string( _settings.gate_timeout.count() ) );
  try
  {
    tx.exec( "SELECT pg_advisory_lock( hive.contexts_compaction_gate_key() )" );
  }
  catch ( const pqxx::sql_error& e )
  {
    if ( e.sqlstate() != LOCK_NOT_AVAILABLE )
      throw;
    tx.exec( "RESET lock_timeout" );
    skipped( "applications' iterations kept the gate", pages_before, milliseconds_since( gate_start ) );
    return;
  }
  const int64_t gate_wait = milliseconds_since( gate_start );

  tx.exec( "SET lock_timeout = " + std::to_string( _settings.lock_timeout.count() ) );
  const auto rewrite_start = fc::time_point::now();
  bool compacted = true;
  try
  {
    tx.exec( "VACUUM FULL hafd.contexts" );
  }
  catch ( const pqxx::sql_error& e )
  {
    if ( e.sqlstate() != LOCK_NOT_AVAILABLE )
      throw;
    compacted = false;
  }
  const int64_t rewrite_duration = milliseconds_since( rewrite_start );
  tx.exec( "RESET lock_timeout" );
  tx.exec( "SELECT pg_advisory_unlock( hive.contexts_compaction_gate_key() )" );

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

void contexts_compactor::skipped( const char* reason, int64_t pages, int64_t gate_wait )
{
  ++_consecutive_skips;
  if ( _consecutive_skips >= _settings.skips_before_warning )
    wlog( "Compaction of hafd.contexts (${pages} pages) skipped ${n} times in a row: ${reason} (gate wait ${gate} ms); it will be retried at the next block",
          ( "pages", pages )( "n", _consecutive_skips )( "reason", reason )( "gate", gate_wait ) );
  else
    ilog( "Compaction of hafd.contexts (${pages} pages) skipped, ${n} times in a row: ${reason} (gate wait ${gate} ms); it will be retried at the next block",
          ( "pages", pages )( "n", _consecutive_skips )( "reason", reason )( "gate", gate_wait ) );
}

} } } // namespace hive::plugins::sql_serializer
