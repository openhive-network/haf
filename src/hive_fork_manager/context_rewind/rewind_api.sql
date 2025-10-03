CREATE OR REPLACE FUNCTION hive.context_create(
      _name hafd.context_name
    , _schema TEXT
    , _fork_id BIGINT = 1
    , _irreversible_block INT = 0
    , _is_forking BOOLEAN = TRUE
    , _is_attached BOOLEAN = TRUE
    , _stages hafd.application_stages = NULL
)
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __new_context_id INTEGER;
    __min_events_id INTEGER;
BEGIN
    IF NOT _name SIMILAR TO '[a-zA-Z0-9_]+' THEN
        RAISE EXCEPTION 'Incorrect context name %, only characters a-z A-Z 0-9 _ are allowed', _name;
    END IF;

    -- it could be null when hived has not yet initialized db
    -- during initialization by hived it is changed to 0
    SELECT MIN(id) INTO __min_events_id FROM hafd.events_queue;

    EXECUTE format( 'CREATE TABLE %I.%I( hive_rowid BIGSERIAL )', _schema, _name );
    INSERT INTO hafd.contexts(
          name
        , current_block_num
        , irreversible_block
        , events_id
        , fork_id
        , owner
        , is_forking
        , last_active_at
        , schema
        , baseclass_id
        , stages
    )
    VALUES(
           _name
          , 0
          , _irreversible_block
          , __min_events_id
          , _fork_id
          , current_user
          , _is_forking
          , NOW()
          , _schema
          , ( _schema || '.' || _name )::regclass
          , _stages
    )
    RETURNING id INTO __new_context_id
    ;

    INSERT INTO hafd.contexts_attachment( context_id, is_attached, owner )
    VALUES( __new_context_id, _is_attached, current_user );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.context_remove( _name hafd.context_name )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hafd.contexts.id%TYPE := NULL;
    __context_schema TEXT;
BEGIN
    SELECT hc.id, hc.schema INTO __context_id, __context_schema FROM hafd.contexts hc WHERE hc.name = _name;

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'Context % does not exist', _name;
    END IF;

    PERFORM hive.log_context( _name, 'REMOVED'::hafd.context_event );

    PERFORM hive.unregister_table( hrt.origin_table_schema, hrt.origin_table_name )
    FROM hafd.registered_tables hrt
    WHERE hrt.context_id = __context_id;

    DELETE FROM hafd.contexts_attachment WHERE context_id = __context_id;
    DELETE FROM hafd.contexts WHERE id = __context_id;

    EXECUTE format( 'DROP TABLE IF EXISTS %I.%I', __context_schema, _name );
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
    RETURN EXISTS( SELECT 1 FROM hafd.contexts hc WHERE hc.name = _name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.context_next_block( _name TEXT )
    RETURNS INTEGER
    LANGUAGE 'sql'
    VOLATILE
AS
$BODY$
UPDATE hafd.contexts
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
    -- we cannot use ALTER TABLE DISABLE TRIGGERS because DDL event trigger cause an error:
    -- Cannot ALTER TABLE "table" because it has pending trigger events, but only when origin tables have contstraints
    UPDATE hafd.contexts SET back_from_fork = TRUE WHERE name = _context AND current_block_num > _block_num_before_fork;

    SET CONSTRAINTS ALL DEFERRED;

    PERFORM
    hive.back_from_fork_one_table(
                  hrt.origin_table_schema
                , hrt.origin_table_name
                , hrt.shadow_table_name
                , _block_num_before_fork
            )
    FROM hafd.registered_tables hrt
    JOIN hafd.contexts hc ON hrt.context_id = hc.id
    WHERE hc.name = _context AND hc.current_block_num > _block_num_before_fork
    ORDER BY hrt.id;

    UPDATE hafd.contexts
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
    __current_block_num INTEGER := NULL;
    __current_irreversible_block INTEGER := NULL;
BEGIN
    SELECT ct.id, ct.current_block_num, ct.irreversible_block
    FROM hafd.contexts ct WHERE ct.name=_context
    INTO __context_id, __current_block_num, __current_irreversible_block;

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'Unknown context %', _context;
    END IF;

    -- we are interested at which moment detach occur
    PERFORM hive.log_context( _context, 'DETACHED'::hafd.context_event );

    PERFORM hive.context_back_from_fork( _context, __current_irreversible_block );

    PERFORM
    hive.remove_obsolete_operations( hrt.shadow_table_name, __current_block_num )
            FROM hafd.registered_tables hrt
            JOIN hafd.contexts hc ON hc.id = hrt.context_id
            WHERE hc.name = _context
            ORDER BY hrt.id;

    PERFORM hive.detach_table( hrt.origin_table_schema, hrt.origin_table_name )
    FROM hafd.registered_tables hrt
    WHERE hrt.context_id = __context_id;

    UPDATE hafd.contexts
    SET events_id = hive.unreachable_event_id()
    WHERE id = __context_id;

    UPDATE hafd.contexts_attachment
    SET is_attached = FALSE
    WHERE context_id = __context_id;
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
    FROM hafd.contexts ct
    JOIN hafd.contexts_attachment hca ON hca.context_id = ct.id
    WHERE ct.name=_context AND hca.is_attached = FALSE
    INTO __context_id, __current_block_num;

    IF __context_id IS NULL THEN
            RAISE EXCEPTION 'Unknown context % or context is already attached', _context;
    END IF;

    IF __current_block_num > _last_synced_block THEN
        RAISE EXCEPTION 'Context % has already processed block nr %', _context, _last_synced_block;
    END IF;


    PERFORM hive.attach_table( hrt.origin_table_schema, hrt.origin_table_name, __context_id )
    FROM hafd.registered_tables hrt
    WHERE hrt.context_id = __context_id;

    UPDATE hafd.contexts
    SET
        current_block_num = _last_synced_block
      , events_id = 0
    WHERE id = __context_id;

    UPDATE hafd.contexts_attachment
    SET is_attached = TRUE
    WHERE context_id = __context_id;

    PERFORM hive.log_context( _context, 'ATTACHED'::hafd.context_event );
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
    SELECT irreversible_block FROM hafd.contexts hc WHERE hc.name = _context INTO __current_irreversible;

    IF _block_num < __current_irreversible THEN
            RAISE EXCEPTION 'The proposed block number of irreversible block is lower than the current one for context %', _context;
    END IF;

    UPDATE hafd.contexts  SET irreversible_block = _block_num
                            , last_active_at = NOW()
    WHERE name = _context;

    PERFORM
    hive.remove_obsolete_operations( hrt.shadow_table_name, _block_num )
            FROM hafd.registered_tables hrt
            JOIN hafd.contexts hc ON hc.id = hrt.context_id
            WHERE hc.name = _context
            ORDER BY hrt.id;
END;
$BODY$
;
