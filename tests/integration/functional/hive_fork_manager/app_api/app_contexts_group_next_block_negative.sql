DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'attached_context', FALSE );
    PERFORM hive.app_create_context( 'attached_context_not_insync', FALSE );
    PERFORM hive.app_create_context( 'detached_context', FALSE );
    PERFORM hive.app_create_context( 'forking_context' );
    PERFORM hive.app_context_detach( 'detached_context' );

    UPDATE hive.contexts ctx
    SET current_block_num = 100
    WHERE ctx.name = 'attached_context_not_insync';

    CREATE SCHEMA A;
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.forking_context );
END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
BEGIN
    BEGIN
        PERFORM hive.app_next_block( ARRAY[ 'not_existed_context', 'attached_context' ] );
        ASSERT FALSE, 'No expected exception for unexisted context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_next_block( ARRAY[ 'attached_context', 'detached_context' ] );
        ASSERT FALSE, 'No expected exception for a detached context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_next_block( ARRAY[] );
        ASSERT FALSE, 'No expected exception for an emoty array of contexts';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_next_block( ARRAY[ 'attached_context', 'forking_context' ] );
        ASSERT FALSE, 'No expected exception for mixing forking and non-forking contexts';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_next_block( ARRAY[ 'attached_context', 'attached_context_not_insync' ] );
        ASSERT FALSE, 'No expected exception for non in sync cntexts';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;





