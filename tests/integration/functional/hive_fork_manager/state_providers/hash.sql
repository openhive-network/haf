

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __keyauth_before_hash TEXT;
    __keyauth_after_hash TEXT;
    __all_before_hashes TEXT;
    __all_after_hashes TEXT;
BEGIN
    ASSERT ( SELECT 1 FROM hive.calculate_state_provider_hashes() WHERE provider = 'ACCOUNTS' ) IS NOT NULL
        , 'ACCOUNTS not hashed';

    ASSERT ( SELECT 1 FROM hive.calculate_state_provider_hashes() WHERE provider = 'KEYAUTH' ) IS NOT NULL
        , 'KEYAUTH not hashed';

    ASSERT ( SELECT 1 FROM hive.calculate_state_provider_hashes() WHERE provider = 'METADATA' ) IS NOT NULL
        , 'METADATA not hashed';

    ASSERT ( SELECT COUNT(*) FROM hive.calculate_state_provider_hashes() ) = 3
        , 'More   than 3 known providers are hashed';

    SELECT STRING_AGG( hash, '|') FROM hive.calculate_state_provider_hashes() INTO __all_before_hashes;
    SELECT * FROM hive.calculate_state_provider_hash( 'KEYAUTH'::hafd.state_providers ) INTO __keyauth_before_hash;

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

    SELECT STRING_AGG( hash, '|') FROM hive.calculate_state_provider_hashes() INTO __all_after_hashes;
    SELECT * FROM hive.calculate_state_provider_hash( 'KEYAUTH'::hafd.state_providers ) INTO __keyauth_after_hash;

    ASSERT __all_after_hashes != __all_before_hashes, 'Hashes not changed after modification';
    ASSERT __keyauth_after_hash != __keyauth_before_hash, 'Hash not changed after modification';
END;
$BODY$;