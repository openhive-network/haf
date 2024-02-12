CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
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


    PERFORM hive.push_block(
            ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        );

    PERFORM hive.push_block(
            ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'alice_context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_impersonal_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'alice_impersonal_context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_impersonal_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_next_block( ARRAY[ 'alice_impersonal_context', 'alice_context' ] );
    PERFORM hive.app_next_block( ARRAY[ 'alice_impersonal_context', 'alice_context' ] );
    ASSERT ( SELECT current_block_num FROM hive.contexts WHERE name = 'alice_impersonal_context' ) = 2, 'alice_impersonal_context cb!= 2';
    ASSERT ( SELECT current_block_num FROM hive.contexts WHERE name = 'alice_context' ) = 2, 'alice_context cb!= 2';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$

BEGIN
    BEGIN
        PERFORM hive.app_next_block( ARRAY[ 'alice_impersonal_context', 'alice_context' ] );
        ASSERT FALSE, 'alice can move alice_impersonal_context';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;