
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
  _test1 INT;
BEGIN
    ASSERT (SELECT hive.convert_to_block_num('2016-06-22 19:10:21-07')) = 1, 'Results on = block 1 do not match';
    ASSERT (SELECT hive.convert_to_block_num('1')) = 1, 'Results on block-num 1 do not match';
    ASSERT (SELECT hive.convert_to_block_num('2016-06-22 19:10:56-07')) = 4, 'Results on > block 4 do not match';
    ASSERT (SELECT hive.convert_to_block_num('2016-06-22 19:10:54-07')) = 3, 'Results on > block 3 do not match';
    ASSERT (SELECT hive.convert_to_block_num(NULL)) IS NULL, 'conversion did not return NULL';
END;
$BODY$
;
