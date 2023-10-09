CREATE FUNCTION run_consensus_replay_pg(text, text, text, int, int, int) RETURNS bool
AS '$libdir/csp_driver_extension', 'run_consensus_replay_pg'
LANGUAGE C STRICT;
