
CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.connect( 'test', 0, 0, 0, TRUE, TRUE );
    -- Call enable_lite_schema() again - should be idempotent
    PERFORM hive.enable_lite_schema();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT hive.is_lite_schema(), 'lite_schema flag not set after idempotent call';
    ASSERT NOT EXISTS (SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name='blocks_reversible'), 'blocks_reversible should not exist';
END;
$BODY$
;
