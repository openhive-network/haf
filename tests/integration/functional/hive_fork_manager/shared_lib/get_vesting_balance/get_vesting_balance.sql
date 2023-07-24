DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
	INSERT INTO hive.blocks
    VALUES
          ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 312785920, 5435823, 1000, 1000, 1000, 2000, 2000 )
        , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 312785920, 0, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.blocks_reversible
    VALUES
           ( 3, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 312785920, 5435823, 1000, 1000, 1000, 2000, 2000, 1 )
         , ( 4, '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 312785920, 5435823, 1000, 1000, 1000, 2000, 2000, 1 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

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
BEGIN
    ASSERT (SELECT hive.get_vesting_balance(1, 12312213124132120)) = 708464368554262962, 'Results on block 1 do not match';
    ASSERT (SELECT hive.get_vesting_balance(2, 12312312412)) IS NULL, 'Function did not return NULL';
    ASSERT (SELECT hive.get_vesting_balance(3, 12312213124132120)) = 708464368554262962, 'Results on block 3 do not match';
    ASSERT (SELECT hive.get_vesting_balance(4, 12312213124132120)) = 708464368554262962, 'Results on block 4 do not match';
END;
$BODY$
;

