
CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.connect( 'test', 0, 0, 0, TRUE, TRUE );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT hive.is_lite_schema(), 'lite_schema flag not set';
    ASSERT hive.is_lite_mode(), 'lite_mode flag not set';

    -- Reversible tables should still exist but be empty
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks_reversible ) = 0, 'blocks_reversible should be empty';
    ASSERT ( SELECT COUNT(*) FROM hafd.transactions_reversible ) = 0, 'transactions_reversible should be empty';
    ASSERT ( SELECT COUNT(*) FROM hafd.operations_reversible ) = 0, 'operations_reversible should be empty';
    ASSERT ( SELECT COUNT(*) FROM hafd.accounts_reversible ) = 0, 'accounts_reversible should be empty';

    -- Fork table should still exist (kept for compatibility)
    ASSERT EXISTS (SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name='fork'), 'fork table should exist';

    -- Contexts columns should still exist (kept for compatibility)
    ASSERT EXISTS (SELECT FROM information_schema.columns WHERE table_schema='hafd' AND table_name='contexts' AND column_name='is_forking'), 'is_forking column should exist';
    ASSERT EXISTS (SELECT FROM information_schema.columns WHERE table_schema='hafd' AND table_name='contexts' AND column_name='fork_id'), 'fork_id column should exist';

    -- Global views should be recreated as irreversible-only
    ASSERT EXISTS (SELECT FROM pg_views WHERE schemaname='hive' AND viewname='blocks_view'), 'hive.blocks_view should exist';
END;
$BODY$
;
