-- Regression test for https://gitlab.syncad.com/hive/haf/-/issues/333
--
-- Scenario: a fork arrives while consistent_block lags behind the fork's common block.
-- Blocks in the range (consistent_block, common_block] are shared by both branches and exist
-- in the reversible tables only under the OLD fork id (the post-fork re-dump starts above the
-- common block).  hive.remove_obsolete_reversible_data() used to delete ALL rows of older fork
-- ids regardless of height, so the first hive.set_irreversible() call destroyed those rows
-- before a later call could copy them to the irreversible tables -- making the next
-- hive.set_irreversible() violate fk_1_hive_irreversible_data and killing hived.
--
-- The failure requires TWO set_irreversible calls (hived advances irreversibility one block at
-- a time): the first call's cleanup destroys the rows above its target, the second call needs them.

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

    PERFORM hive.end_massive_sync( 1 ); -- consistent_block = 1

    -- live blocks 2,3,4 arrive on fork 1
    PERFORM hive.push_block(
         ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL, NULL, NULL, NULL, NULL, NULL
    );
    PERFORM hive.push_block(
         ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL, NULL, NULL, NULL, NULL, NULL
    );
    PERFORM hive.push_block(
         ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL, NULL, NULL, NULL, NULL, NULL
    );

    -- fork switch: block 4 is popped, blocks 2 and 3 are common to both branches
    -- (consistent_block is still 1, so blocks 2,3 exist only as fork 1 rows)
    PERFORM hive.back_from_fork( 3 );

    PERFORM hive.push_block(
         ( 4, '\xBADD41', '\xCAFE40', '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL, NULL, NULL, NULL, NULL, NULL
    );
    PERFORM hive.push_block(
         ( 5, '\xBADD51', '\xCAFE51', '2016-06-22 19:10:34-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL, NULL, NULL, NULL, NULL, NULL
    );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- hived advances irreversibility one block at a time; the first call's cleanup must not
    -- destroy the only copies of blocks 3 (fork 1 row at/below the fork's common block)
    PERFORM hive.set_irreversible( 2 );
    PERFORM hive.set_irreversible( 3 );
    PERFORM hive.set_irreversible( 4 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks WHERE num = 2 AND hash = '\xBADD20' ) = 1, 'Block 2 missing from irreversible blocks';
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks WHERE num = 3 AND hash = '\xBADD30' ) = 1, 'Block 3 missing from irreversible blocks (shared block below fork common block was lost)';
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks WHERE num = 4 AND hash = '\xBADD41' ) = 1, 'Block 4 missing from irreversible blocks or wrong fork won';
    ASSERT ( SELECT consistent_block FROM hafd.hive_state ) = 4, 'consistent_block did not advance to 4';

    -- the popped fork-1 block 4 must not survive as irreversible
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks WHERE hash = '\xBADD40' ) = 0, 'Popped fork-1 block 4 wrongly copied to irreversible';

    -- block 5 is still reversible only
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks_reversible WHERE num = 5 ) = 1, 'Block 5 missing from reversible blocks';
END;
$BODY$
;
