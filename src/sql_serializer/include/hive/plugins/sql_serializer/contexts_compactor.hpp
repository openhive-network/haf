#pragma once

#include <chrono>
#include <condition_variable>
#include <cstdint>
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
 * A run first takes the advisory key hive.contexts_compaction_gate_key() exclusively, which waits for
 * the applications' iterations in progress (they hold it shared) and holds new ones back, then runs
 * VACUUM FULL with a short lock_timeout, so hived's own statements queue behind it for at most that long.
 * A run that gets neither within its bounds is skipped and tried again at the next block.
 */
class contexts_compactor
{
public:
  struct settings
  {
    // hafd.contexts is compacted once its heap has more pages than this
    uint32_t threshold_pages = 64;
    // how long a run waits for the applications' iterations to release the gate
    std::chrono::milliseconds gate_timeout{ 5'000 };
    // how long VACUUM FULL waits for its lock on hafd.contexts
    std::chrono::milliseconds lock_timeout{ 100 };
    // consecutive skips after which every further skip is logged as a warning
    uint32_t skips_before_warning = 100;
  };

  contexts_compactor( std::string db_url, settings compaction_settings );
  ~contexts_compactor();

  contexts_compactor( const contexts_compactor& ) = delete;
  contexts_compactor& operator=( const contexts_compactor& ) = delete;

  /// Called for every block hived applies; requests a run when is_live. Never waits for a run.
  void on_block( bool is_live );

private:
  void run();
  void compact_if_needed( pqxx::connection& conn );
  void skipped( const char* reason, int64_t pages, int64_t gate_wait );

  const std::string _db_url;
  const settings _settings;

  std::mutex _mutex;
  std::condition_variable _requested_cv;
  bool _requested = false;
  bool _stopping = false;

  // used by the compaction thread only
  uint32_t _consecutive_skips = 0;
  int64_t _pages_after_last_compaction = 0;

  std::thread _thread;
};

} } } // namespace hive::plugins::sql_serializer
