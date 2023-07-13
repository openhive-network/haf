DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.operation_types
    VALUES
    ( 0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
         , ( 2, 'OP 2', FALSE )
         , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hive.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
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
    PERFORM hive.app_create_context( 'context' );
    CREATE SCHEMA A;
    CREATE TABLE A.table1( id INT) INHERITS( hive.context );

    -- move to irreversible block (1,1)
    PERFORM hive.app_next_block( 'context' );
    -- move to irreversible block (2,2)
    PERFORM hive.app_next_block( 'context' );
    INSERT INTO A.table1( id ) VALUES (1);
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
    PERFORM hive.app_context_set_non_forking( 'context' ); -- back to block 1
    INSERT INTO A.table1( id ) VALUES (10);
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
DECLARE
        __result hive.blocks_range;
BEGIN
    ASSERT EXISTS ( SELECT * FROM hive.contexts WHERE name='context' AND is_attached = TRUE ), 'Attach flag is still set';
    ASSERT ( SELECT current_block_num FROM hive.contexts WHERE name='context' ) = 1, 'Wrong current_block_num';
    ASSERT ( SELECT detached_block_num FROM hive.contexts WHERE name='context' ) IS NULL, 'detached_block_num was not set to NULL';
    ASSERT ( SELECT is_forking FROM hive.contexts WHERE name='context' ) = FALSE, 'context is is still marked as forking';

    ASSERT ( SELECT COUNT(*) FROM hive.shadow_a_table1 ) = 0, 'Trigger inserted something into shadow table1';

    SELECT * INTO __result FROM hive.app_next_block( 'context' );
    ASSERT __result IS NULL, 'Non forking context reach reversible block';

    -- only 10 (insert  for irreversible block 1) shall stay in a context's table
    ASSERT ( SELECT COUNT(*) FROM A.table1 ) = 1, 'Wrong number of rows in A.table1';
    ASSERT ( SELECT COUNT(*) FROM A.table1 WHERE id=1 ) = 0, 'Reversible id=1 still in the table A.table1';
END;
$BODY$
;




