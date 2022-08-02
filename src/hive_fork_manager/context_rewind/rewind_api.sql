CREATE OR REPLACE FUNCTION hive.context_create( _name hive.context_name, _fork_id BIGINT = 1, _irreversible_block INT = 0 )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    CALL hive.dlogs(_name, 'Entering context_create');
    IF NOT _name SIMILAR TO '[a-zA-Z0-9_]+' THEN
        RAISE EXCEPTION 'Incorrect context name %, only characters a-z A-Z 0-9 _ are allowed', name;
    END IF;

    EXECUTE format( 'CREATE TABLE hive.%I( hive_rowid BIGSERIAL )', _name );
    INSERT INTO hive.contexts( name, current_block_num, irreversible_block, is_attached, events_id, fork_id, owner )
    VALUES( _name, 0, _irreversible_block, TRUE, 0, _fork_id, current_user );
    CALL hive.dlogs(_name, 'Exiting context_create');
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.context_remove( _name hive.context_name )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE := NULL;
BEGIN
    CALL hive.dlogs(_name, 'Entering context_remove');
    SELECT hc.id INTO __context_id FROM hive.contexts hc WHERE hc.name = _name;

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'Context % does not exist', _name;
    END IF;

    PERFORM hive.unregister_table( hrt.origin_table_schema, hrt.origin_table_name )
    FROM hive.registered_tables hrt
    WHERE hrt.context_id = __context_id;

    DELETE FROM hive.contexts WHERE id = __context_id;

    EXECUTE format( 'DROP TABLE hive.%I', _name );
    CALL hive.dlogs(_name, 'Exiting context_remove');

END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.context_exists( _name TEXT )
    RETURNS BOOL
    LANGUAGE 'plpgsql'
    STABLE
AS
$BODY$
BEGIN
    CALL hive.dlogs(_name, 'Entering context_exists');
    CALL hive.dlogs(_name, 'Exiting context_exists');

    RETURN EXISTS( SELECT 1 FROM hive.contexts hc WHERE hc.name = _name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.context_next_block( _name TEXT )
    RETURNS INTEGER
    LANGUAGE 'sql'
    VOLATILE
AS
$BODY$
CALL hive.dlogs(_name, 'Entering context_next_block');
UPDATE hive.contexts
SET current_block_num = current_block_num + 1
WHERE name = _name
CALL hive.dlogs(_name, 'Exiting context_next_block');

    RETURNING current_block_num
$BODY$
;

CREATE OR REPLACE FUNCTION hive.context_back_from_fork( _context TEXT, _block_num_before_fork INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __trigger_name TEXT;
    __registerd_table_schema TEXT;
    __registerd_table_name TEXT;
BEGIN
    CALL hive.dlogs(_context, 'Entering context_back_from_fork');

    -- we need a flag for back_from_fork to returns from triggers immediatly
    -- we cannot use ALTER TABLE DISABLE TRIGGERS because DDL event trigger cause an error:
    -- Cannot ALTER TABLE "table" because it has pending trigger events, but only when origin tables have contstraints
    UPDATE hive.contexts SET back_from_fork = TRUE WHERE name = _context AND current_block_num > _block_num_before_fork;

    SET CONSTRAINTS ALL DEFERRED;

    PERFORM
    hive.back_from_fork_one_table(
                  hrt.origin_table_schema
                , hrt.origin_table_name
                , hrt.shadow_table_name
                , hrt.origin_table_columns
                , _block_num_before_fork
            )
    FROM hive.registered_tables hrt
    JOIN hive.contexts hc ON hrt.context_id = hc.id
    WHERE hc.name = _context AND hc.current_block_num > _block_num_before_fork
    ORDER BY hrt.id;

    UPDATE hive.contexts
    SET   current_block_num = _block_num_before_fork
        , back_from_fork = FALSE
    WHERE name = _context AND current_block_num > _block_num_before_fork;
    CALL hive.dlogs(_context, 'Exiting context_back_from_fork');

END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.context_detach( _context TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __context_id INTEGER := NULL;
BEGIN
    CALL hive.dlogs(_context, 'Entering context_detach');
    SELECT ct.id FROM hive.contexts ct WHERE ct.name=_context INTO __context_id;

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'Unknown context %', _context;
    END IF;

    PERFORM hive.detach_table( hrt.origin_table_schema, hrt.origin_table_name )
    FROM hive.registered_tables hrt
    WHERE hrt.context_id = __context_id;

    UPDATE hive.contexts
    SET is_attached = FALSE,
        detached_block_num = NULL,
        current_block_num = CASE WHEN current_block_num = 0 THEN 0 ELSE current_block_num - 1 END
    WHERE id = __context_id;
    CALL hive.dlogs(_context, 'Exiting context_detach');

END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.context_attach( _context TEXT, _last_synced_block INT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __context_id INTEGER := NULL;
    __current_block_num INTEGER := NULL;
BEGIN
    CALL hive.dlogs(_context, 'Entering context_attach');
    SELECT ct.id, ct.current_block_num
    FROM hive.contexts ct
    WHERE ct.name=_context AND ct.is_attached = FALSE
    INTO __context_id, __current_block_num;

    IF __context_id IS NULL THEN
            RAISE EXCEPTION 'Unknown context % or context is already attached', _context;
    END IF;

    IF __current_block_num > _last_synced_block THEN
        call hive.elogs(_context, format('Context %s has already processed block nr %s', _context, _last_synced_block), TRUE);
    END IF;


    PERFORM hive.attach_table( hrt.origin_table_schema, hrt.origin_table_name, __context_id )
    FROM hive.registered_tables hrt
    WHERE hrt.context_id = __context_id;

    UPDATE hive.contexts
    SET
        current_block_num = _last_synced_block
      , is_attached = TRUE
    WHERE id = __context_id;
    CALL hive.dlogs(_context, 'Exiting context_attach');

END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.context_set_irreversible_block( _context TEXT, _block_num INTEGER )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __current_irreversible INTEGER;
BEGIN
    CALL hive.dlogs(_context, 'Entering context_set_irreversible_block');
    -- validate new irreversible
    SELECT irreversible_block FROM hive.contexts hc WHERE hc.name = _context INTO __current_irreversible;

    IF _block_num < __current_irreversible THEN
            RAISE EXCEPTION 'The proposed block number of irreversible block is lower than the current one for context %', _context;
    END IF;

    UPDATE hive.contexts  SET irreversible_block = _block_num WHERE name = _context;

    PERFORM
    hive.remove_obsolete_operations( hrt.shadow_table_name, _block_num )
            FROM hive.registered_tables hrt
            JOIN hive.contexts hc ON hc.id = hrt.context_id
            WHERE hc.name = _context
            ORDER BY hrt.id;
    CALL hive.dlogs(_context, 'Exiting context_set_irreversible_block');

END;
$BODY$
;