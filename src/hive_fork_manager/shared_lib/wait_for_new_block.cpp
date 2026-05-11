#include <psql_utils/postgres_includes.hpp>

extern "C" {
#include <storage/latch.h>
#include <utils/wait_event.h>
}

extern "C"
{

/**
 * Wait until either an asynchronous notification arrives on a channel this
 * session is listening on, the given timeout elapses, or the postmaster
 * dies.
 *
 * The session must have already issued LISTEN on the relevant channel(s)
 * (and committed it) for notifications to wake this call. The callee does
 * not consult the notification queue — any latch-set event causes a wake.
 * Spurious wakeups are possible and benign; the caller is expected to
 * re-check its condition and call again if needed.
 *
 * @param _timeout_ms Maximum time to wait in milliseconds.
 * @return true if woken by a latch event (typically a NOTIFY),
 *         false if the timeout expired with no wake event.
 */
PG_FUNCTION_INFO_V1(wait_for_new_block);
Datum wait_for_new_block(PG_FUNCTION_ARGS)
{
  int32 timeout_ms = PG_GETARG_INT32(0);

  int rc = WaitLatch(MyLatch,
                     WL_LATCH_SET | WL_TIMEOUT | WL_EXIT_ON_PM_DEATH,
                     timeout_ms,
                     PG_WAIT_EXTENSION);

  ResetLatch(MyLatch);
  CHECK_FOR_INTERRUPTS();

  PG_RETURN_BOOL((rc & WL_LATCH_SET) != 0);
}

} /* extern "C" */
