
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    INSERT INTO hafd.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    PERFORM hive.end_massive_sync(1);

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

    -- cleans eq because no context uses it,
    -- it may create hole between irreversible blocks and blocks in events queue
    PERFORM hive.set_irreversible( 2 );

    PERFORM hive.push_block(
            ( 4, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  ); -- new context on events id 0
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __blocks hive.blocks_range := NULL;
BEGIN
    SELECT * INTO __blocks FROM hive.app_next_block( 'context' );
    ASSERT __blocks IS NOT NULL, '(1) null block range';
    ASSERT __blocks = (1,2), '(1) wrong range of blocks';

    SELECT * INTO __blocks FROM hive.app_next_block( 'context' );
    ASSERT __blocks IS NOT NULL, '(2) null block range';
    ASSERT __blocks = (2,2), '(2) wrong range of blocks';

    SELECT * INTO __blocks FROM hive.app_next_block( 'context' );
    ASSERT __blocks IS NOT NULL, '(3) null block range';
    ASSERT __blocks = (3,3), '(3) wrong range of blocks';

    SELECT * INTO __blocks FROM hive.app_next_block( 'context' );
    ASSERT __blocks IS NULL, '(4) not null block range for irreversible event';

    SELECT * INTO __blocks FROM hive.app_next_block( 'context' );
    ASSERT __blocks IS NOT NULL, '(5) null block range';
    ASSERT __blocks = (4,4), '(5) wrong range of blocks';
END;
$BODY$
;