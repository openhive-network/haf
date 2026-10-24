CREATE OR REPLACE PROCEDURE test_hived_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.request_freeze_of_irreversible();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT (
        SELECT array_agg( format( '%s.%s:%s:%s', schema_name, table_name, kind, status ) ORDER BY table_name )
        FROM hafd.vacuum_requests
    ) = ARRAY[
          'hafd.accounts:freeze:requested'
        , 'hafd.blocks:freeze:requested'
        , 'hafd.operations:freeze:requested'
        , 'hafd.transactions:freeze:requested'
        , 'hafd.transactions_multisig:freeze:requested'
    ], 'hive.request_freeze_of_irreversible should request a freeze vacuum of each large irreversible table';

    ASSERT (
        SELECT array_agg( relname::TEXT ORDER BY relname )
        FROM pg_class
        WHERE relnamespace = 'hafd'::REGNAMESPACE
          AND reloptions @> ARRAY['autovacuum_vacuum_insert_scale_factor=0.005']
    ) = ARRAY[ 'account_operations', 'blocks', 'operations', 'transactions' ]
    , 'large insert-only irreversible tables should have a small autovacuum insert scale factor';
END;
$BODY$
;
