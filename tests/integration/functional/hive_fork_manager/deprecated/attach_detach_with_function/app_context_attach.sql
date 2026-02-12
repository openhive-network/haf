
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.blocks
    VALUES
          ( hafd.make_block_id(1, 0), '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(2, 0), '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(3, 0), '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES (5, 'initminer', hafd.make_block_id(1, 0))
    ;

    -- Set block 2 as irreversible (required for attach at block 2)
    UPDATE hafd.hive_state SET consistent_block = hafd.make_block_id(2, 0);

    INSERT INTO hafd.fork VALUES( 2, 2, '2016-06-22 19:10:24-07'::timestamp );
    INSERT INTO hafd.fork VALUES( 3, 3, '2016-06-22 19:10:25-07'::timestamp );

    CREATE SCHEMA A;
    PERFORM hive.app_create_context( 'context', 'a' );
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context );
    PERFORM hive.app_context_detach( 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.app_set_current_block_num( 'context', 2 );
    PERFORM hive.app_context_attach( 'context' );
    INSERT INTO A.table1( id ) VALUES (10);
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT * FROM hafd.contexts hc JOIN hafd.contexts_attachment hca ON hca.context_id=hc.id WHERE hc.name='context' AND hca.is_attached = TRUE ), 'Attach flag is still not set';
    ASSERT EXISTS ( SELECT * FROM hafd.contexts WHERE name='context' AND fork_id = 2 ), 'Wrong fork_id';

    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_a_table1 ) = 1, 'Trigger inserted something into shadow table1';
END;
$BODY$
;


