
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
	INSERT INTO hafd.blocks
    VALUES
          ( hafd.make_block_id(1, 0), '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 312785920, 5435823, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(2, 0), '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 312785920, 0, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.blocks
    VALUES
           ( hafd.make_block_id(3, 1), '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 312785920, 5435823, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(4, 1), '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 312785920, 5435823, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES (5, 'initminer', hafd.make_block_id(1, 0))
    ;

END;
$BODY$
;


CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT (SELECT hive.get_vesting_balance(1, 12312213124132120)) = 708464368554262962, 'Results on block 1 do not match';
    ASSERT (SELECT hive.get_vesting_balance(2, 12312312412)) IS NULL, 'Function did not return NULL';
    ASSERT (SELECT hive.get_vesting_balance(3, 12312213124132120)) = 708464368554262962, 'Results on block 3 do not match';
    ASSERT (SELECT hive.get_vesting_balance(4, 12312213124132120)) = 708464368554262962, 'Results on block 4 do not match';
END;
$BODY$
;

