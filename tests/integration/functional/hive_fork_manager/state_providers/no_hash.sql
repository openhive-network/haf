-- check if there is no registered state_provider, then hash is not computed


CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __database_hash_before TEXT;
    __database_hash_after TEXT;
BEGIN
    ASSERT ( SELECT 1 FROM hive.calculate_state_provider_hashes() WHERE provider = 'ACCOUNTS' ) IS NULL
        , 'ACCOUNTS hashed';

    ASSERT ( SELECT 1 FROM hive.calculate_state_provider_hashes() WHERE provider = 'KEYAUTH' ) IS NULL
        , 'KEYAUTH hashed';

    ASSERT ( SELECT 1 FROM hive.calculate_state_provider_hashes() WHERE provider = 'METADATA' ) IS NULL
        , 'METADATA hashed';

    ASSERT ( SELECT COUNT(*) FROM hive.calculate_state_provider_hashes() ) = 0
        , 'More   than 0 known providers are hashed';

    SELECT schema_hash FROM hive.create_database_hash('hafd')  INTO __database_hash_before;

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

    SELECT schema_hash FROM hive.create_database_hash('hafd')  INTO __database_hash_after;

    ASSERT __database_hash_after = __database_hash_before, 'Unused state provider has impact on database hash';
END;
$BODY$;