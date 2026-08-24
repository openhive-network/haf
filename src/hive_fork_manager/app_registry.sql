-- Application registry API (issue #341). See applications.sql for the model.

-- Registers (or re-registers, keeping the paused flag) an application: a group of
-- contexts owned by the caller, and optionally the procedure a block-processing
-- driver calls with each delivered range. Contexts may belong to one application only.
CREATE OR REPLACE FUNCTION hive.app_register( _name TEXT, _contexts hive.contexts_group, _process_procedure TEXT = NULL )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __missing TEXT;
    __taken TEXT;
    __taken_by TEXT;
BEGIN
    PERFORM pg_advisory_xact_lock( hashtext('hive_catalog_modification') );

    SELECT c INTO __missing
    FROM unnest( _contexts ) AS c
    WHERE NOT EXISTS ( SELECT 1 FROM hafd.contexts hc WHERE hc.name = c )
    LIMIT 1;
    IF __missing IS NOT NULL THEN
        RAISE EXCEPTION 'Cannot register application %: context % does not exist', _name, __missing;
    END IF;

    IF EXISTS ( SELECT 1 FROM hafd.contexts hc WHERE hc.name = ANY( _contexts ) AND NOT hive.can_impersonate( current_user, hc.owner ) ) THEN
        RAISE EXCEPTION 'Cannot register application %: role % does not own all of its contexts', _name, current_user;
    END IF;

    SELECT a.name, c INTO __taken_by, __taken
    FROM hafd.applications a, unnest( _contexts ) AS c
    WHERE a.name != _name AND a.contexts @> ARRAY[ c::TEXT ]
    LIMIT 1;
    IF __taken IS NOT NULL THEN
        RAISE EXCEPTION 'Cannot register application %: context % already belongs to application %', _name, __taken, __taken_by;
    END IF;

    IF _process_procedure IS NOT NULL AND to_regprocedure( _process_procedure || '( hive.blocks_range )' ) IS NULL THEN
        RAISE EXCEPTION 'Cannot register application %: procedure %( hive.blocks_range ) does not exist', _name, _process_procedure;
    END IF;

    INSERT INTO hafd.applications( name, contexts, process_procedure, owner )
    VALUES ( _name, _contexts::TEXT[], _process_procedure, current_user )
    ON CONFLICT ( name ) DO UPDATE
    SET contexts = EXCLUDED.contexts, process_procedure = EXCLUDED.process_procedure;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_unregister( _name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __dependents TEXT;
BEGIN
    PERFORM pg_advisory_xact_lock( hashtext('hive_catalog_modification') );

    SELECT string_agg( d.application, ', ' ) INTO __dependents
    FROM hafd.application_dependencies d WHERE d.depends_on = _name;
    IF __dependents IS NOT NULL THEN
        RAISE WARNING 'Unregistering application %: applications % depended on it and are no longer gated by it', _name, __dependents;
    END IF;

    DELETE FROM hafd.applications WHERE name = _name;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application % is not registered', _name;
    END IF;
END;
$BODY$
;

-- Declares that _name must never process a block before _depends_on has processed
-- and committed it. Dependencies form a DAG; cycles are rejected.
CREATE OR REPLACE FUNCTION hive.app_add_dependency( _name TEXT, _depends_on TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM pg_advisory_xact_lock( hashtext('hive_catalog_modification') );

    IF NOT EXISTS ( SELECT 1 FROM hafd.applications WHERE name = _name ) THEN
        RAISE EXCEPTION 'Application % is not registered', _name;
    END IF;
    IF NOT EXISTS ( SELECT 1 FROM hafd.applications WHERE name = _depends_on ) THEN
        RAISE EXCEPTION 'Application % is not registered', _depends_on;
    END IF;
    IF _name = _depends_on THEN
        RAISE EXCEPTION 'Application % cannot depend on itself', _name;
    END IF;

    -- adding _name -> _depends_on closes a cycle iff _name is reachable from _depends_on
    IF EXISTS (
        WITH RECURSIVE reach( name ) AS (
            SELECT _depends_on
            UNION
            SELECT d.depends_on FROM hafd.application_dependencies d JOIN reach r ON d.application = r.name
        )
        SELECT 1 FROM reach WHERE name = _name
    ) THEN
        RAISE EXCEPTION 'Cannot make application % depend on %: it would create a dependency cycle', _name, _depends_on;
    END IF;

    INSERT INTO hafd.application_dependencies( application, depends_on )
    VALUES ( _name, _depends_on )
    ON CONFLICT DO NOTHING;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_remove_dependency( _name TEXT, _depends_on TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    DELETE FROM hafd.application_dependencies WHERE application = _name AND depends_on = _depends_on;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application % does not depend on %', _name, _depends_on;
    END IF;
END;
$BODY$
;

-- A paused application receives no block ranges (hive.app_next_iteration returns
-- NULL) until resumed; its loop keeps running and its contexts stay attached.
CREATE OR REPLACE FUNCTION hive.app_pause( _name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    UPDATE hafd.applications SET paused = TRUE WHERE name = _name;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application % is not registered', _name;
    END IF;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.app_resume( _name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    UPDATE hafd.applications SET paused = FALSE WHERE name = _name;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application % is not registered', _name;
    END IF;
END;
$BODY$
;

-- TRUE when any registered application containing one of _contexts is paused.
CREATE OR REPLACE FUNCTION hive.app_is_paused( _contexts hive.contexts_group )
    RETURNS BOOL
    LANGUAGE sql
    STABLE
AS
$BODY$
    SELECT EXISTS (
        SELECT 1 FROM hafd.applications a
        WHERE a.paused AND a.contexts && _contexts::TEXT[]
    );
$BODY$
;

-- Highest block the applications containing _contexts may be given: the lowest
-- committed position among all contexts of all applications they depend on.
-- NULL when there are no dependencies. Direct dependencies suffice: a dependency
-- is itself gated by its own dependencies, so it can never be ahead of them.
--
-- hafd.contexts.current_block_num is updated in the same transaction as the
-- application's work for that block (hive.app_next_iteration commits the previous
-- iteration before advancing it), so other sessions observe it only once that work
-- is committed: a value of N means "N is fully processed and visible".
CREATE OR REPLACE FUNCTION hive.app_dependencies_block_limit( _contexts hive.contexts_group )
    RETURNS INTEGER
    LANGUAGE sql
    STABLE
AS
$BODY$
    SELECT MIN( dc.current_block_num )
    FROM hafd.applications a
    JOIN hafd.application_dependencies d ON d.application = a.name
    JOIN hafd.applications dep ON dep.name = d.depends_on
    JOIN hafd.contexts dc ON dc.name = ANY( dep.contexts )
    WHERE a.contexts && _contexts::TEXT[];
$BODY$
;

-- Removes _context from the application it belongs to (if any); the application
-- is unregistered when it loses its last context. Called by hive.context_remove.
CREATE OR REPLACE FUNCTION hive.app_registry_context_removed( _context hafd.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __app TEXT;
    __contexts TEXT[];
BEGIN
    SELECT a.name, array_remove( a.contexts, _context::TEXT ) INTO __app, __contexts
    FROM hafd.applications a WHERE a.contexts @> ARRAY[ _context::TEXT ];

    IF __app IS NULL THEN
        RETURN;
    END IF;

    IF CARDINALITY( __contexts ) = 0 THEN
        PERFORM hive.app_unregister( __app );
    ELSE
        UPDATE hafd.applications SET contexts = __contexts WHERE name = __app;
    END IF;
END;
$BODY$
;
