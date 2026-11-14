#pragma once

#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <thread>

#include <pqxx/pqxx>

namespace hive { namespace plugins { namespace sql_serializer {

/**
 * Rewrites hafd.contexts with VACUUM FULL while hived is live and the table has outgrown a threshold:
 * plain VACUUM cannot shrink it (vacuum_truncate=false). The work runs on its own thread and connection,
 * so the block-processing thread only signals it.
 *
 * A run first takes the advisory key hive.contexts_compaction_gate_key() exclusively, which holds new
 * applications' iterations back (they take it shared). It never queues for the key: a queued exclusive
 * request would block every later shared request, so one application iterating for minutes would stall
 * all the others. Instead it polls pg_try_advisory_lock until the gate timeout, which succeeds only at
 * a moment no iteration is running. Holding the key, it runs VACUUM FULL with lock_timeout, which bounds
 * only how long VACUUM FULL waits for its own lock on the table; once granted, hived's statements and
 * new iterations wait for the whole rewrite.
 * A run that gets neither within its bounds is skipped. Whatever its outcome, the next run starts at
 * a block applied after it ended.
 */
class contexts_compactor
{
public:
  struct settings
  {
    // hafd.contexts is compacted once its heap has more pages than this; 0 disables compaction
    uint32_t threshold_pages = 64;
    // how long a run polls for the gate before it is skipped
    std::chrono::milliseconds gate_timeout{ 5'000 };
    // how long VACUUM FULL waits for its lock on hafd.contexts
    std::chrono::milliseconds lock_timeout{ 100 };
    // pause between two attempts to take the gate
    std::chrono::milliseconds gate_poll_interval{ 50 };
    // consecutive skips after which every further skip is logged as a warning
    uint32_t skips_before_warning = 100;

    bool is_enabled() const { return threshold_pages > 0; }
  };

  /// Throws std::invalid_argument when a timeout or the poll interval is not positive:
  /// PostgreSQL reads a lock_timeout of 0 as "wait forever".
  contexts_compactor( std::string db_url, settings compaction_settings );
  /// Cancels a query of a run in progress and waits for the run to end.
  ~contexts_compactor();

  contexts_compactor( const contexts_compactor& ) = delete;
  contexts_compactor& operator=( const contexts_compactor& ) = delete;

  /// Called for every block hived applies; requests a run when is_live and compaction is enabled.
  /// Never waits for a run.
  void on_block( bool is_live );

private:
  void run();
  void connect_if_needed();
  void drop_connection();
  bool is_stopping();
  void compact_if_needed( pqxx::connection& conn );
  bool enter_gate( pqxx::nontransaction& tx );
  void skipped( const char* reason, int64_t pages, int64_t gate_wait );

  const std::string _db_url;
  const settings _settings;

  std::mutex _mutex;
  std::condition_variable _cv;
  bool _requested = false;
  bool _stopping = false;
  // set and reset by the compaction thread under _mutex, so the destructor can cancel its query
  std::unique_ptr< pqxx::connection > _conn;

  // used by the compaction thread only
  uint32_t _consecutive_skips = 0;
  int64_t _pages_after_last_compaction = 0;

  std::thread _thread;
};

} } } // namespace hive::plugins::sql_serializer
