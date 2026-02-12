CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __test_value BIGINT := 0x7EADBEEF36B6B6B6;
BEGIN
    ASSERT ( SELECT hafd.operation_id_to_block_num( __test_value ) ) = 0x7EADBEEF, 'Wrong block num != 0x7EADBEEF';
    ASSERT ( SELECT hafd.operation_id_to_pos( __test_value ) ) = 0x36B6B6B6, 'Wrong pos != 0x36B6B6B6';

    ASSERT ( SELECT hafd.operation_id( 0x7EADBEEF, 0x36B6B6B6 ) ) = 0x7EADBEEF36B6B6B6, 'wrong operation id';
    END;
$BODY$
;
