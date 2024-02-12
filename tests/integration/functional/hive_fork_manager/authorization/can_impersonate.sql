CREATE OR REPLACE PROCEDURE test_hived_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT hive.can_impersonate(  'alice_impersonal', 'alice' ) ) = TRUE, 'alice_impersonal not alice impersonal';
    ASSERT ( SELECT hive.can_impersonate(  'alice', 'alice' ) ) = TRUE, 'alice not alice impersonal';
    ASSERT ( SELECT hive.can_impersonate(  'bob', 'alice' ) ) = FALSE, 'bob is alice impersonal';
    ASSERT ( SELECT hive.can_impersonate(  'alice', 'alice_impersonal' ) ) = FALSE, 'alice is alice_impersonal impersonal';
END;
$BODY$
;