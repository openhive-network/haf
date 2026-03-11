
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

    -- Reversible tables should be dropped
    ASSERT NOT EXISTS (SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name='blocks_reversible'), 'blocks_reversible still exists';
    ASSERT NOT EXISTS (SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name='transactions_reversible'), 'transactions_reversible still exists';
    ASSERT NOT EXISTS (SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name='operations_reversible'), 'operations_reversible still exists';
    ASSERT NOT EXISTS (SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name='transactions_multisig_reversible'), 'transactions_multisig_reversible still exists';
    ASSERT NOT EXISTS (SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name='accounts_reversible'), 'accounts_reversible still exists';
    ASSERT NOT EXISTS (SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name='account_operations_reversible'), 'account_operations_reversible still exists';
    ASSERT NOT EXISTS (SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name='applied_hardforks_reversible'), 'applied_hardforks_reversible still exists';

    -- Fork table should be dropped
    ASSERT NOT EXISTS (SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name='fork'), 'fork table still exists';

    -- Forking columns should be dropped from contexts
    ASSERT NOT EXISTS (SELECT FROM information_schema.columns WHERE table_schema='hafd' AND table_name='contexts' AND column_name='is_forking'), 'is_forking column still exists';
    ASSERT NOT EXISTS (SELECT FROM information_schema.columns WHERE table_schema='hafd' AND table_name='contexts' AND column_name='back_from_fork'), 'back_from_fork column still exists';
    ASSERT NOT EXISTS (SELECT FROM information_schema.columns WHERE table_schema='hafd' AND table_name='contexts' AND column_name='fork_id'), 'fork_id column still exists';
END;
$BODY$
;
