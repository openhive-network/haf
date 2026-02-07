CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __test_value hafd.operations.id%TYPE := 0x7EADBEEF36B6B688;
BEGIN
    ASSERT ( SELECT hafd.operation_id_to_block_num( __test_value ) ) = 0x7EADBEEF, 'Wrong block num != 0x7EADBEEF';
    ASSERT ( SELECT hafd.operation_id_to_pos( __test_value ) ) = 0x36B6B688, 'Wrong pos != 0x36B6B688';

    ASSERT ( SELECT hafd.operation_id( 0x7EADBEEF, 0x36B6B688 ) ) = 0x7EADBEEF36B6B688, 'wrong operation id';
    END;
$BODY$
;
