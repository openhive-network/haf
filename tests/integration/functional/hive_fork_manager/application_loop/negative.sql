
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __context_stages hafd.application_stages :=
        ARRAY[
            ('massive',2 ,100 )::hafd.application_stage
            , hafd.live_stage()
            ];
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( 'attached_context', _schema => 'a', _is_forking => FALSE, _stages => __context_stages );
    PERFORM hive.app_create_context( 'attached_context_not_insync', _schema => 'a', _is_forking => FALSE, _stages => __context_stages );
    PERFORM hive.app_create_context( 'detached_context', _schema => 'a', _is_forking => FALSE, _stages => __context_stages );
    PERFORM hive.app_create_context( 'forking_context', 'a', _stages => __context_stages );
    PERFORM hive.app_create_context( 'nostaged_context', 'a' );
    PERFORM hive.app_context_detach( 'detached_context' );


    UPDATE hafd.contexts ctx
    SET current_block_num = 100
    WHERE ctx.name = 'attached_context_not_insync';

    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.forking_context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
BEGIN
    BEGIN
        PERFORM hive.app_next_iteration( ARRAY[ 'not_existed_context', 'attached_context' ], __blocks );
        ASSERT FALSE, 'No expected exception for unexisted context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_next_iteration( ARRAY[ 'attached_context', 'detached_context' ], __blocks );
        ASSERT FALSE, 'No expected exception for mixed detached context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_next_iteration( ARRAY[], __blocks );
        ASSERT FALSE, 'No expected exception for an empty array of contexts';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_next_iteration( ARRAY[ 'attached_context', 'forking_context' ], __blocks );
        ASSERT FALSE, 'No expected exception for mixing forking and non-forking contexts';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_next_iteration( ARRAY[ 'attached_context', 'attached_context_not_insync' ], __blocks );
        ASSERT FALSE, 'No expected exception for non in sync cntexts';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_next_iteration( ARRAY[ 'nostaged_context' ], __blocks );
        ASSERT FALSE, 'No expected exception for using context without stages';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;





