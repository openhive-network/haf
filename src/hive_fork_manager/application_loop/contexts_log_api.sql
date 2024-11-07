CREATE FUNCTION hive.log_context( _context_name hafd.context_name, _reason hafd.context_event )
    RETURNS VOID
    LANGUAGE plpgsql
AS
$$
DECLARE
    __ctx_current_block INTEGER;
    __ctx_current_fork  BIGINT;
    __ctx_stage hafd.stage_name;

    __head_block INTEGER;
    __head_fork BIGINT;
BEGIN
    SELECT hc.current_block_num, hc.fork_id
    INTO __ctx_current_block, __ctx_current_fork
    FROM hafd.contexts hc
    WHERE hc.name = _context_name;

    __ctx_stage = hive.get_current_stage_name( _context_name );

    SELECT MAX(b.num)
    INTO __head_block
    FROM hive.blocks_view;

    SELECT MAX(b.num)
    INTO __head_block
    FROM hive.blocks_view;

    SELECT MAX(hf.id)
    INTO __head_fork
    FROM hive.fork hf;

    INSERT INTO hafd.contexts_log
    VALUES (_context_name, __ctx_stage, _reason, date(), __ctx_current_block, __ctx_current_fork, __head_block, __head_fork )
    ;
END;
$$