DROP FUNCTION IF EXISTS hive.context_create;
CREATE FUNCTION hive.context_create( _name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    IF NOT _name SIMILAR TO '[a-zA-Z0-9_]+' THEN
        RAISE EXCEPTION 'Incorrect context name %, only characters a-z A-Z 0-9 _ are allowed', name;
    END IF;

    INSERT INTO hive.context( name, current_block_num, irreversible_block, is_attached ) VALUES( _name, 0, 0, TRUE );
END;
$BODY$
;


DROP FUNCTION IF EXISTS hive.context_exists;
CREATE FUNCTION hive.context_exists( _name TEXT )
    RETURNS BOOL
    LANGUAGE 'plpgsql'
    STABLE
AS
$BODY$
BEGIN
    RETURN EXISTS( SELECT 1 FROM hive.context hc WHERE hc.name = _name );
END;
$BODY$
;

DROP FUNCTION IF EXISTS hive.context_next_block;
CREATE FUNCTION hive.context_next_block( _name TEXT )
    RETURNS INTEGER
    LANGUAGE 'sql'
    VOLATILE
AS
$BODY$
UPDATE hive.context
SET current_block_num = current_block_num + 1
WHERE name = _name
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
    -- we need a flag for back_from_fork to returns from triggers immediatly
    -- we cannot use ALTER TABLE DISABE TRIGGERS because DDL event trigger cause an error:
    -- Cannot ALTER TABLE "table" because it has pending trigger events, but only when origin tables have contstraints
    UPDATE hive.context SET back_from_fork = TRUE WHERE name = _context AND current_block_num > _block_num_before_fork;

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
    JOIN hive.context hc ON hrt.context_id = hc.id
    WHERE hc.name = _context AND hc.current_block_num > _block_num_before_fork
    ORDER BY hrt.id;

    UPDATE hive.context
    SET   current_block_num = _block_num_before_fork
        , back_from_fork = FALSE
    WHERE name = _context AND current_block_num > _block_num_before_fork;
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
    SELECT ct.id FROM hive.context ct WHERE ct.name=_context INTO __context_id;

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'Unknown context %', _context;
    END IF;

    PERFORM hive.detach_table( hrt.origin_table_schema, hrt.origin_table_name )
    FROM hive.registered_tables hrt
    WHERE hrt.context_id = __context_id;

    UPDATE hive.context
    SET is_attached = FALSE
    WHERE id = __context_id;
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
    SELECT ct.id, ct.current_block_num
    FROM hive.context ct
    WHERE ct.name=_context AND ct.is_attached = FALSE
    INTO __context_id, __current_block_num;

    IF __context_id IS NULL THEN
            RAISE EXCEPTION 'Unknown context % or context is already attached', _context;
    END IF;

    IF __current_block_num > _last_synced_block THEN
        RAISE EXCEPTION 'Context % has already processed block nr %', _context, _last_synced_block;
    END IF;


    PERFORM hive.attach_table( hrt.origin_table_schema, hrt.origin_table_name )
    FROM hive.registered_tables hrt
    WHERE hrt.context_id = __context_id;

    UPDATE hive.context
    SET
        current_block_num = _last_synced_block
      , is_attached = TRUE
    WHERE id = __context_id;
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
    -- validate new irreversible
    SELECT irreversible_block FROM hive.context hc WHERE hc.name = _context INTO __current_irreversible;

    IF _block_num < __current_irreversible THEN
                RAISE EXCEPTION 'The proposed block number of irreversible block is lower than the current one for context %', _context;
    END IF;

    UPDATE hive.context  SET irreversible_block = _block_num WHERE name = _context;

    PERFORM
    hive.remove_obsolete_operations( hrt.shadow_table_name, _block_num )
            FROM hive.registered_tables hrt
            JOIN hive.context hc ON hc.id = hrt.context_id
            WHERE hc.name = _context
            ORDER BY hrt.id;
END;
$BODY$
;