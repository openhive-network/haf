CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __test_value hive.operations.id%TYPE := 0x7EADBEEFB6B6B688;
BEGIN
    ASSERT ( SELECT hive.operation_id_to_block_num( __test_value ) ) = 0x7EADBEEF, 'Wrong block num != 0x7EADBEEF';
    ASSERT ( SELECT hive.operation_id_to_type_id( __test_value ) ) = 0x88, 'Wrong type id != 0x88';
    ASSERT ( SELECT hive.operation_id_to_pos( __test_value ) ) = 0xB6B6B6, 'Wrong pos != 0xB6B6B6';

    ASSERT ( SELECT hive.operation_id( 0x7EADBEEF, 0x88, 0xB6B6B6 ) ) = 0x7EADBEEFB6B6B688;
    END;
$BODY$
;