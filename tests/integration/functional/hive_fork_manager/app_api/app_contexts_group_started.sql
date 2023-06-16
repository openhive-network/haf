DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
DECLARE
        __account hive.accounts%ROWTYPE;
BEGIN
    __account = ( 5, 'initminer', 1 );
    PERFORM hive.push_block(
            ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , ARRAY[ __account ]
        , NULL
        , NULL
        );
    PERFORM hive.set_irreversible( 1 );

    PERFORM hive.app_create_context( 'context_a' );
    PERFORM hive.app_create_context( 'context_b' );
    PERFORM hive.app_create_context( 'context_c' );
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
BEGIN
    PERFORM hive.app_next_block( 'context_c' );
END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT ( SELECT hive.app_are_contexts_not_started( ARRAY[ 'context_a' ] ) ) = TRUE, 'context_a is started';
    ASSERT ( SELECT hive.app_are_contexts_not_started( ARRAY[ 'context_a', 'context_b' ] ) ) = TRUE, 'context_a and context_b are started';
    ASSERT ( SELECT hive.app_are_contexts_not_started( ARRAY[ 'context_c' ] ) ) = FALSE, 'context_c is not started';
    ASSERT ( SELECT hive.app_are_contexts_not_started( ARRAY[ 'context_a', 'context_c' ] ) ) = FALSE, 'context_a or context_c are started';
END;
$BODY$
;


