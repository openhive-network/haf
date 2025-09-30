
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
	INSERT INTO hafd.blocks
    VALUES
          ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 312785920, 5435823, 1000, 1000, 1000, 2000, 2000 )
        , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 312785920, 0, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.blocks_reversible
    VALUES
           ( 3, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 312785920, 5435823, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 4, '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 312785920, 5435823, 1000, 1000, 1000, 2000, 2000, 1 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

END;
$BODY$
;


CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  __exception_message1 TEXT;
  __exception_message2 TEXT;
  __exception_message3 TEXT;
  _test1 INT;
  _test2 INT;
  _test3 INT;
BEGIN
    ASSERT (SELECT first_block FROM hive.convert_to_blocks_range('2016-06-22 19:10:20-07','1')) = 1, 'Results on < block 1 do not match';
    ASSERT (SELECT first_block FROM hive.convert_to_blocks_range('2016-06-22 19:10:21-07','1')) = 1, 'Results on = block 1 do not match';
    ASSERT (SELECT last_block  FROM hive.convert_to_blocks_range('1','2016-06-22 19:10:26-07')) = 3, 'Results on > block 3 do not match';
    ASSERT (SELECT last_block  FROM hive.convert_to_blocks_range('1','2016-06-22 19:10:25-07')) = 2, 'Results on = block 2 do not match';
    ASSERT (SELECT last_block  FROM hive.convert_to_blocks_range('1', NULL)) IS NULL, 'last_block did not return NULL';
    ASSERT (SELECT first_block FROM hive.convert_to_blocks_range(NULL, '1')) IS NULL, 'first_block did not return NULL';

    BEGIN PERFORM hive.convert_to_block_num('0'); ASSERT FALSE, 'Block 0 should fail'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN PERFORM hive.convert_to_block_num('-1'); ASSERT FALSE, 'Block -1 should fail'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN PERFORM hive.convert_to_block_num('-100'); ASSERT FALSE, 'Block -100 should fail'; EXCEPTION WHEN OTHERS THEN NULL; END;


    BEGIN PERFORM hive.convert_to_blocks_range('0', '10'); ASSERT FALSE, 'from-block=0 should fail'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN PERFORM hive.convert_to_blocks_range('1', '0'); ASSERT FALSE, 'to-block=0 should fail'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN PERFORM hive.convert_to_blocks_range('-5', '10'); ASSERT FALSE, 'from-block=-5 should fail'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN PERFORM hive.convert_to_blocks_range('1', '-10'); ASSERT FALSE, 'to-block=-10 should fail'; EXCEPTION WHEN OTHERS THEN NULL; END;

    -- Test timestamps in wrong order (to < from)
    BEGIN PERFORM hive.convert_to_blocks_range('2016-06-22 19:10:55', '2016-06-22 19:10:21'); ASSERT FALSE, 'Reversed timestamps should fail'; EXCEPTION WHEN OTHERS THEN NULL; END;

    -- Test timestamps outside of block range
    BEGIN PERFORM hive.convert_to_blocks_range('2015-01-01', '2015-12-31'); ASSERT FALSE, 'Timestamps before blocks should fail'; EXCEPTION WHEN OTHERS THEN NULL; END;

    -- Test mixed invalid cases
    BEGIN PERFORM hive.convert_to_blocks_range('0', '2016-06-22'); ASSERT FALSE, 'Invalid from-block with valid timestamp should fail'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN PERFORM hive.convert_to_blocks_range('2016-06-22', '-1'); ASSERT FALSE, 'Valid timestamp with invalid to-block should fail'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN PERFORM hive.convert_to_blocks_range('abc', '2016-06-22'); ASSERT FALSE, 'Invalid format with valid timestamp should fail'; EXCEPTION WHEN OTHERS THEN NULL; END;

END;
$BODY$
;
