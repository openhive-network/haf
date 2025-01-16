

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __keyauth_before_hash TEXT;
    __keyauth_after_hash TEXT;
    __all_before_hashes TEXT;
    __all_after_hashes TEXT;
    __database_hash_before TEXT;
    __database_hash_before1 TEXT;
    __database_hash_after TEXT;
BEGIN
    ASSERT ( SELECT 1 FROM hive_update.calculate_state_provider_hashes(enum_range(NULL::hafd.state_providers)) WHERE provider = 'ACCOUNTS' ) IS NOT NULL
        , 'ACCOUNTS not hashed';

    ASSERT ( SELECT 1 FROM hive_update.calculate_state_provider_hashes(enum_range(NULL::hafd.state_providers)) WHERE provider = 'KEYAUTH' ) IS NOT NULL
        , 'KEYAUTH not hashed';

    ASSERT ( SELECT 1 FROM hive_update.calculate_state_provider_hashes(enum_range(NULL::hafd.state_providers)) WHERE provider = 'METADATA' ) IS NOT NULL
        , 'METADATA not hashed';

    ASSERT ( SELECT COUNT(*) FROM hive_update.calculate_state_provider_hashes(enum_range(NULL::hafd.state_providers)) ) = 3
        , 'More   than 3 known providers are hashed';

    SELECT STRING_AGG( hash, '|') FROM hive_update.calculate_state_provider_hashes(enum_range(NULL::hafd.state_providers)) INTO __all_before_hashes;
    SELECT * FROM hive_update.calculate_state_provider_hash( 'KEYAUTH'::hafd.state_providers ) INTO __keyauth_before_hash;

    SELECT hive_update.create_database_hash()  INTO __database_hash_before;
    SELECT hive_update.create_database_hash(ARRAY['METADATA']::hafd.state_providers[])  INTO __database_hash_before1;

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

    SELECT STRING_AGG( hash, '|') FROM hive_update.calculate_state_provider_hashes(enum_range(NULL::hafd.state_providers)) INTO __all_after_hashes;
    SELECT * FROM hive_update.calculate_state_provider_hash( 'KEYAUTH'::hafd.state_providers ) INTO __keyauth_after_hash;
    SELECT hive_update.create_database_hash()  INTO __database_hash_after;

    ASSERT __all_after_hashes != __all_before_hashes, 'Hashes not changed after modification';
    ASSERT __keyauth_after_hash != __keyauth_before_hash, 'Hash not changed after modification';
    ASSERT __database_hash_before != __database_hash_after, 'DB Hash not changed after modification';
    ASSERT __database_hash_before1 != __database_hash_after, 'DB Hash not changed after modification 1';
END;
$BODY$;