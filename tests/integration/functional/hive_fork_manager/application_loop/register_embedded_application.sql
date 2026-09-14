-- Application registry (issue #345): an application embedded in another one (the
-- balance tracker inside haf_block_explorer) re-runs its install script on an
-- installed database. Registering it again must be a no-op that leaves the
-- embedding registration intact, while a context taken by an application that
-- does not contain all of the requested contexts is still rejected.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name => 'outer_ctx', _schema => 'a', _is_forking => FALSE );
    PERFORM hive.app_create_context( _name => 'embedded_ctx', _schema => 'a', _is_forking => FALSE );
    PERFORM hive.app_create_context( _name => 'other_ctx', _schema => 'a', _is_forking => FALSE );

    -- first install: the embedded application registers standalone, then the
    -- embedding one takes its context over
    PERFORM hive.app_register( 'embedded_app', ARRAY[ 'embedded_ctx' ] );
    PERFORM hive.app_unregister( 'embedded_app' );
    PERFORM hive.app_register( 'outer_app', ARRAY[ 'outer_ctx', 'embedded_ctx' ] );
    PERFORM hive.app_pause( 'outer_app' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __partial_rejected BOOLEAN := FALSE;
BEGIN
    -- re-install of both applications
    PERFORM hive.app_register( 'embedded_app', ARRAY[ 'embedded_ctx' ] );
    PERFORM hive.app_register( 'outer_app', ARRAY[ 'outer_ctx', 'embedded_ctx' ] );

    BEGIN
        PERFORM hive.app_register( 'partial_app', ARRAY[ 'embedded_ctx', 'other_ctx' ] );
    EXCEPTION WHEN OTHERS THEN
        __partial_rejected := TRUE;
    END;
    ASSERT __partial_rejected, 'registration overlapping another application was accepted';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS ( SELECT 1 FROM hafd.applications WHERE name IN ( 'embedded_app', 'partial_app' ) ), 'embedded or partial application got registered';
    ASSERT ( SELECT contexts FROM hafd.applications WHERE name = 'outer_app' ) = ARRAY[ 'outer_ctx', 'embedded_ctx' ], 'embedding registration was changed';
    ASSERT hive.app_is_paused( ARRAY[ 'embedded_ctx' ] ), 'embedding application lost its paused flag';
END;
$BODY$
;
