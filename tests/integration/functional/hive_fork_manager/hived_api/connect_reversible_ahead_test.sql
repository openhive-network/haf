CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __block hafd.blocks%ROWTYPE;
BEGIN
    INSERT INTO hafd.blocks
    VALUES
       ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    PERFORM hive.end_massive_sync( 1 );

    -- block 2 is only reversible: hived stopped before it became irreversible
    __block = ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 );
    PERFORM hive.push_block( __block, NULL, NULL, NULL, NULL, NULL, NULL );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.connect( '123456789', 1, 1, 0 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks ) = 1, 'Irreversible blocks changed';
    ASSERT ( SELECT COUNT(*) FROM hafd.hived_connections WHERE block_num = 1 AND git_sha = '123456789' ) = 1, 'No expected connection saved';
    ASSERT ( SELECT COUNT(*) FROM hafd.fork ) = 2, 'Reversible blocks above hived head were not rewound';
    ASSERT EXISTS ( SELECT FROM hafd.events_queue WHERE event = 'BACK_FROM_FORK' ), 'No BACK_FROM_FORK event added';
END
$BODY$
;
