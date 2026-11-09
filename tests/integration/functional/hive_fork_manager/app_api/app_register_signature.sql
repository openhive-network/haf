-- Applications detect the registry by probing hive.app_register's exact
-- four-parameter signature with to_regprocedure, so it must have no other arity.

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT to_regprocedure( 'hive.app_register(text, hive.contexts_group, text, text)' ) IS NOT NULL, 'the four-parameter hive.app_register is missing';
    ASSERT to_regprocedure( 'hive.app_register(text, hive.contexts_group, text, text, text)' ) IS NULL, 'a five-parameter hive.app_register exists';
    ASSERT ( SELECT count(*) FROM pg_proc WHERE proname = 'app_register' AND pronamespace = 'hive'::regnamespace ) = 1
        , 'hive.app_register has more than one overload';
END;
$BODY$
;
