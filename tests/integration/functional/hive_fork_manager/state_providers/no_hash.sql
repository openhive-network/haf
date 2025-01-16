-- check if there is no registered state_provider, then hash is not computed


CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __database_hash_before TEXT;
    __database_hash_after TEXT;
BEGIN
    ASSERT ( SELECT 1 FROM hive_update.calculate_state_provider_hashes( ARRAY['KEYAUTH', 'METADATA']::hafd.state_providers[] ) WHERE provider = 'ACCOUNTS' ) IS NULL
        , 'ACCOUNTS hashed';

    ASSERT ( SELECT 1 FROM hive_update.calculate_state_provider_hashes( ARRAY['KEYAUTH', 'METADATA']::hafd.state_providers[] ) WHERE provider = 'KEYAUTH' ) IS NOT NULL
        , 'KEYAUTH not hashed';

    ASSERT ( SELECT 1 FROM hive_update.calculate_state_provider_hashes( ARRAY['KEYAUTH', 'METADATA']::hafd.state_providers[] ) WHERE provider = 'METADATA' ) IS NOT NULL
        , 'METADATA not hashed';

    ASSERT ( SELECT hive_update.calculate_state_provider_hashes( ARRAY[]::hafd.state_providers[] ) ) IS NULL, 'NOT NULL returned for empty state providers';

    SELECT hive_update.create_database_hash(ARRAY['METADATA']::hafd.state_providers[])  INTO __database_hash_before;

    EXECUTE format( 'CREATE OR REPLACE FUNCTION hive.start_provider_keyauth( _context hafd.context_name )
    RETURNS TEXT[]
    LANGUAGE plpgsql
    VOLATILE
    AS
    $$
    BEGIN
        RETURN '''';
    END;
    $$
    ;');

    SELECT hive_update.create_database_hash(ARRAY['METADATA']::hafd.state_providers[])  INTO __database_hash_after;

    ASSERT __database_hash_after = __database_hash_before, 'Unused state provider has impact on database hash';
END;
$BODY$;