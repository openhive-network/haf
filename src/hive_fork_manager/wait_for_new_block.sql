-- Block the calling session until a NOTIFY arrives on a channel it is
-- listening on, the timeout elapses, or the postmaster dies.
--
-- The session must LISTEN to the desired channel(s) and COMMIT the LISTEN
-- before calling this function. Returns true if woken by a latch event
-- (typically a NOTIFY), false on timeout.
CREATE OR REPLACE FUNCTION hive.wait_for_new_block( _timeout_ms INTEGER )
RETURNS BOOLEAN
AS 'MODULE_PATHNAME', 'wait_for_new_block' LANGUAGE C STRICT;
