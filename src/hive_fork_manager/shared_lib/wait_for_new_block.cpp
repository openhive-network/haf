#include <psql_utils/postgres_includes.hpp>

extern "C" {
#include <storage/latch.h>
#include <storage/proc.h>
#include <utils/guc.h>
#include <utils/wait_event.h>
}

extern "C"
{

/*
 * PG_MODULE_MAGIC is defined in operation_base.cpp -- only one allowed
 * per shared library. No need to redefine here.
 *
 * When the GUC below is on, hive.wait_for_new_block emits a NOTICE
 * describing the cleared xmin and the wake reason on every call. Useful
 * for issue #328 validation. Default off; the function emits the same
 * information at DEBUG1 regardless.
 */
static bool wait_for_new_block_debug = false;

void _PG_init(void);
void _PG_init(void)
{
  DefineCustomBoolVariable(
    "hive.wait_for_new_block_debug",
    "When on, hive.wait_for_new_block raises NOTICE messages around each "
    "wait reporting the cleared MyProc->xmin and the wake reason. Useful "
    "for verifying that issue #328 is fixed in a running stack.",
    nullptr,
    &wait_for_new_block_debug,
    false,
    PGC_USERSET,
    0,
    nullptr, nullptr, nullptr);
}

/**
 * Wait until either an asynchronous notification arrives on a channel this
 * session is listening on, the given timeout elapses, or the postmaster
 * dies.
 *
 * The session must have already issued LISTEN on the relevant channel(s)
 * (and committed it) for notifications to wake this call. The callee does
 * not consult the notification queue -- any latch-set event causes a wake.
 * Spurious wakeups are possible and benign; the caller is expected to
 * re-check its condition and call again if needed.
 *
 * For the duration of the WaitLatch this function temporarily clears
 * MyProc->xmin so that other backends do not see this session pinning
 * the global snapshot horizon. The current SQL statement's active
 * snapshot is still pushed, but our advertised xmin is invalid for the
 * duration of the wait, so HOT-prune and autovacuum can advance freely
 * (issue #328 -- without this, the read-only sleep transaction's xmin
 * pins the horizon ~1.5s back across all live-sync apps).
 *
 * IMPORTANT: After this returns the caller MUST NOT depend on the
 * visibility of any rows that became dead during the wait. The intended
 * use site is the "no work, sleep, return NULL" branch in
 * hive.app_next_block, where the caller returns immediately without
 * further table access in the same statement. Calling this from a path
 * that later reads tables in the same SELECT is unsafe.
 *
 * Set hive.wait_for_new_block_debug = on at session scope (or
 * log_min_messages = debug1 server-side) to see per-call NOTICE/DEBUG
 * lines reporting the saved/restored xmin and wake reason.
 *
 * @param _timeout_ms Maximum time to wait in milliseconds.
 * @return true if woken by a latch event (typically a NOTIFY),
 *         false if the timeout expired with no wake event.
 */
PG_FUNCTION_INFO_V1(wait_for_new_block);
Datum wait_for_new_block(PG_FUNCTION_ARGS)
{
  int32 timeout_ms = PG_GETARG_INT32(0);
  TransactionId saved_xmin = MyProc->xmin;
  int rc = 0;

  int debug_level = wait_for_new_block_debug ? NOTICE : DEBUG1;

  ereport(debug_level,
    (errmsg("hive.wait_for_new_block: clearing MyProc->xmin (was %u), timeout %d ms",
      saved_xmin, timeout_ms)));

  PG_TRY();
  {
    /*
     * Release this backend's advertised xmin during the wait so other
     * backends do not see us pinning the global snapshot horizon. The
     * active SQL snapshot stays pushed; we just stop advertising our
     * participation while we are idle on the latch. Restored under
     * PG_CATCH below if anything throws inside WaitLatch.
     */
    MyProc->xmin = InvalidTransactionId;

    rc = WaitLatch(MyLatch,
                   WL_LATCH_SET | WL_TIMEOUT | WL_EXIT_ON_PM_DEATH,
                   timeout_ms,
                   PG_WAIT_EXTENSION);
  }
  PG_CATCH();
  {
    MyProc->xmin = saved_xmin;
    PG_RE_THROW();
  }
  PG_END_TRY();

  MyProc->xmin = saved_xmin;
  ResetLatch(MyLatch);
  CHECK_FOR_INTERRUPTS();

  ereport(debug_level,
    (errmsg("hive.wait_for_new_block: woke (latch=%d, timeout=%d); MyProc->xmin restored to %u",
      (rc & WL_LATCH_SET) != 0, (rc & WL_TIMEOUT) != 0, saved_xmin)));

  PG_RETURN_BOOL((rc & WL_LATCH_SET) != 0);
}

} /* extern "C" */
