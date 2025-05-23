
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    INSERT INTO hafd.operation_types
    VALUES
    ( 0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
         , ( 2, 'OP 2', FALSE )
         , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hafd.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    PERFORM hive.end_massive_sync( 1 );

    PERFORM hive.push_block(
            ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        );

    -- create non-forking context and its table
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( 'context', _schema => 'a', _is_forking =>FALSE );
    CREATE TABLE A.table1( id INT) INHERITS( a.context );

    -- move to irreversible block (1,1)
    PERFORM hive.app_next_block( 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- now it is time to switch to forking context
    PERFORM hive.app_context_set_forking( 'context' );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __second_blocks hive.blocks_range;
BEGIN
    -- move to reversible block
    SELECT * FROM hive.app_next_block( 'context' ) INTO __second_blocks;
    RAISE NOTICE 'Second block=%', __second_blocks;
    ASSERT __second_blocks.first_block = 2 AND __second_blocks.last_block = 2, 'Wrong second block';

    ASSERT EXISTS ( SELECT * FROM hafd.contexts hc JOIN hafd.contexts_attachment hca ON hca.context_id=hc.id WHERE hc.name='context' AND hca.is_attached = TRUE ), 'Attach flag is still set';
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name='context' ) = 2, 'Wrong current_block_num';
    ASSERT ( SELECT is_forking FROM hafd.contexts WHERE name='context' ) = TRUE, 'context is is still marked as non-forking';


    INSERT INTO A.table1( id ) VALUES (10);
    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_a_table1 ) = 1, 'Nothing was inserted into shadow table1';
END
$BODY$
;




