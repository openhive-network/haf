CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    -- Fixed chain id so the golden digests are build-independent (the function
    -- otherwise defaults to this build's HIVE_CHAIN_ID).
    chain TEXT := 'beeab0de00000000000000000000000000000000000000000000000000000000';
    d BYTEA;
    d2 BYTEA;
    rejected BOOLEAN;
BEGIN
    -- Golden vectors: sha256( chain || RFC-8785(JCS(signed_fields)) ), cross-computed
    -- with the Python `rfc8785` reference. l2_transaction_digest must match bit-for-bit.

    -- simple
    d := hive.l2_transaction_digest('{"app":"l2_notes","version":1,"expiration":"2026-06-22T12:00:00","operations":[{"method":"set","params":{"account":"alice","key":"k","value":"v"}}]}'::JSONB, chain);
    ASSERT length(d) = 32, 'digest must be 32 bytes';
    ASSERT encode(d,'hex') = '288ac965bcba7716d98f4a01716ea885a1c62d4d07ad69f41933c1f28b3c1976', 'simple digest mismatch vs rfc8785';

    -- key order must not matter (JCS sorts keys): same content, keys reordered -> same digest
    d2 := hive.l2_transaction_digest('{"operations":[{"params":{"value":"v","account":"alice","key":"k"},"method":"set"}],"expiration":"2026-06-22T12:00:00","version":1,"app":"l2_notes"}'::JSONB, chain);
    ASSERT d2 = d, 'key order must not change the digest (JCS canonicalization)';

    -- optional nonce
    d := hive.l2_transaction_digest('{"app":"x","version":2,"nonce":"e8459c74","expiration":"2026-01-01T00:00:00","operations":[]}'::JSONB, chain);
    ASSERT encode(d,'hex') = '1a67160f9d1afa196e2d80b4b593aa8aee583becc7888db11ef1498c9d78ddc2', 'with_nonce digest mismatch vs rfc8785';

    -- unicode + escaping
    d := hive.l2_transaction_digest('{"app":"x","version":1,"expiration":"2026-01-01T00:00:00","operations":[{"method":"set","params":{"v":"héllo é \"q\" \\b\n"}}]}'::JSONB, chain);
    ASSERT encode(d,'hex') = '09b4d7fbd447c2cc729eedef00af156f84a8e80d872f21fe01bd5cd40e539a42', 'unicode digest mismatch vs rfc8785';

    -- nested objects/arrays
    d := hive.l2_transaction_digest('{"app":"x","version":1,"expiration":"2026-01-01T00:00:00","operations":[{"method":"a","params":{"n":[1,2,3],"m":{"z":1,"a":2}}}]}'::JSONB, chain);
    ASSERT encode(d,'hex') = '6bc26568a8db0ae462a13db6b94bde2494d9d706522ec5fe4066ad0fcc28cd15', 'nested digest mismatch vs rfc8785';

    -- large value carried as a string (out-of-range integers are not allowed as numbers)
    d := hive.l2_transaction_digest('{"app":"x","version":1,"expiration":"2026-01-01T00:00:00","operations":[],"big":"9223372036854775807"}'::JSONB, chain);
    ASSERT encode(d,'hex') = '8a202306b5f0e76e0ff90cfb46116718d97198439294f8f4064df239550e6d31', 'bigint_as_string digest mismatch vs rfc8785';

    -- chain id sensitivity: a different chain id must change the digest
    d  := hive.l2_transaction_digest('{"app":"x","version":1,"expiration":"2026-01-01T00:00:00","operations":[]}'::JSONB, chain);
    d2 := hive.l2_transaction_digest('{"app":"x","version":1,"expiration":"2026-01-01T00:00:00","operations":[]}'::JSONB, '4200000000000000000000000000000000000000000000000000000000000000');
    ASSERT d2 <> d, 'different chain id must change the digest';

    -- Restricted numeric profile: floats and out-of-2^53 integers must be REJECTED.
    rejected := FALSE;
    BEGIN PERFORM hive.l2_transaction_digest('{"app":"x","version":1,"expiration":"2026-01-01T00:00:00","operations":[],"x":1.5}'::JSONB, chain);
    EXCEPTION WHEN OTHERS THEN rejected := TRUE; END;
    ASSERT rejected, 'non-integer number must be rejected';

    rejected := FALSE;
    BEGIN PERFORM hive.l2_transaction_digest('{"app":"x","version":1,"expiration":"2026-01-01T00:00:00","operations":[],"x":100000000000000001}'::JSONB, chain);
    EXCEPTION WHEN OTHERS THEN rejected := TRUE; END;
    ASSERT rejected, 'integer above 2^53-1 must be rejected';

    rejected := FALSE;
    BEGIN PERFORM hive.l2_transaction_digest('{"app":"x","version":1,"expiration":"2026-01-01T00:00:00","operations":[],"x":-9007199254740993}'::JSONB, chain);
    EXCEPTION WHEN OTHERS THEN rejected := TRUE; END;
    ASSERT rejected, 'integer below -(2^53-1) must be rejected';
END;
$BODY$
;
