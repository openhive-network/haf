CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    _result RECORD;
    _count INT;
BEGIN
    -- ==========================================================================
    -- TEST: hive.parse_rc_delegation() with correct array format
    -- JSON format: ["delegate_rc", {"from":"...", "delegatees":[...], "max_rc":...}]
    -- ==========================================================================

    -- Valid single delegatee
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"alice","delegatees":["bob"],"max_rc":1000000000}]'
    );
    ASSERT _count = 1, 'Single delegatee should return 1 row, got ' || _count;

    -- Verify values for single delegatee
    SELECT * INTO _result FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"alice","delegatees":["bob"],"max_rc":1000000000}]'
    );
    ASSERT _result.from_account = 'alice', 'from_account should be alice';
    ASSERT _result.to_account = 'bob', 'to_account should be bob';
    ASSERT _result.max_rc = 1000000000, 'max_rc should be 1000000000';

    -- Valid multiple delegatees should return multiple rows
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"alice","delegatees":["bob","carol","dave"],"max_rc":500000}]'
    );
    ASSERT _count = 3, 'Three delegatees should return 3 rows, got ' || _count;

    -- Verify all delegatees have same max_rc
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"alice","delegatees":["bob","carol"],"max_rc":12345}]'
    ) WHERE max_rc = 12345;
    ASSERT _count = 2, 'All rows should have max_rc=12345';

    -- Real-world example from blockchain
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"bulldog1205","delegatees":["shamlands"],"max_rc":20000000000}]'
    );
    ASSERT _count = 1, 'Real example should return 1 row';

    SELECT * INTO _result FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"bulldog1205","delegatees":["shamlands"],"max_rc":20000000000}]'
    );
    ASSERT _result.from_account = 'bulldog1205', 'from_account should be bulldog1205';
    ASSERT _result.to_account = 'shamlands', 'to_account should be shamlands';
    ASSERT _result.max_rc = 20000000000, 'max_rc should be 20000000000';

    -- max_rc = 0 (delegation removal) should be valid
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"alice","delegatees":["bob"],"max_rc":0}]'
    );
    ASSERT _count = 1, 'max_rc=0 (removal) should return 1 row';

    -- ==========================================================================
    -- TEST: Multiple operations in single custom_json
    -- Format: [["delegate_rc", {...}], ["delegate_rc", {...}], ...]
    -- ==========================================================================

    -- Two delegate_rc operations with different max_rc values
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '[["delegate_rc",{"from":"alice","delegatees":["bob"],"max_rc":1000}],["delegate_rc",{"from":"alice","delegatees":["carol"],"max_rc":2000}]]'
    );
    ASSERT _count = 2, 'Two operations should return 2 rows, got ' || _count;

    -- Verify different max_rc values are preserved
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '[["delegate_rc",{"from":"alice","delegatees":["bob"],"max_rc":1000}],["delegate_rc",{"from":"alice","delegatees":["carol"],"max_rc":2000}]]'
    ) WHERE max_rc = 1000;
    ASSERT _count = 1, 'Should have 1 row with max_rc=1000';

    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '[["delegate_rc",{"from":"alice","delegatees":["bob"],"max_rc":1000}],["delegate_rc",{"from":"alice","delegatees":["carol"],"max_rc":2000}]]'
    ) WHERE max_rc = 2000;
    ASSERT _count = 1, 'Should have 1 row with max_rc=2000';

    -- Multiple operations with multiple delegatees each
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '[["delegate_rc",{"from":"alice","delegatees":["bob","carol"],"max_rc":1000}],["delegate_rc",{"from":"dave","delegatees":["eve","frank","grace"],"max_rc":5000}]]'
    );
    ASSERT _count = 5, 'Two operations with 2+3 delegatees should return 5 rows, got ' || _count;

    -- Mixed operations: only delegate_rc should be parsed
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '[["other_op",{"some":"data"}],["delegate_rc",{"from":"alice","delegatees":["bob"],"max_rc":1000}]]'
    );
    ASSERT _count = 1, 'Should only parse delegate_rc, ignoring other ops, got ' || _count;

    -- Multiple operations where one is invalid (self-delegation) - should still parse valid ones
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '[["delegate_rc",{"from":"alice","delegatees":["alice"],"max_rc":1000}],["delegate_rc",{"from":"bob","delegatees":["carol"],"max_rc":2000}]]'
    );
    ASSERT _count = 1, 'Should skip invalid op and return 1 row for valid op, got ' || _count;

    -- ==========================================================================
    -- Invalid cases - should return empty set (0 rows)
    -- ==========================================================================

    -- NULL input
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(NULL);
    ASSERT _count = 0, 'NULL should return 0 rows';

    -- Empty string
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation('');
    ASSERT _count = 0, 'Empty string should return 0 rows';

    -- Malformed JSON
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation('not json at all');
    ASSERT _count = 0, 'Malformed JSON should return 0 rows';

    -- JSON object instead of array (wrong format)
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '{"type":"delegate_rc_operation","value":{"from":"alice","delegatees":["bob"],"max_rc":1000}}'
    );
    ASSERT _count = 0, 'Object format (not array) should return 0 rows';

    -- Wrong operation type
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["wrong_op",{"from":"alice","delegatees":["bob"],"max_rc":1000}]'
    );
    ASSERT _count = 0, 'Wrong operation type should return 0 rows';

    -- Empty delegatees array
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"alice","delegatees":[],"max_rc":1000}]'
    );
    ASSERT _count = 0, 'Empty delegatees should return 0 rows';

    -- Self-delegation
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"alice","delegatees":["alice"],"max_rc":1000}]'
    );
    ASSERT _count = 0, 'Self-delegation should return 0 rows';

    -- Negative max_rc
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"alice","delegatees":["bob"],"max_rc":-100}]'
    );
    ASSERT _count = 0, 'Negative max_rc should return 0 rows';

    -- Invalid from account name (too short)
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"ab","delegatees":["bob"],"max_rc":1000}]'
    );
    ASSERT _count = 0, 'Invalid from account name should return 0 rows';

    -- Invalid delegatee account name
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"alice","delegatees":["x"],"max_rc":1000}]'
    );
    ASSERT _count = 0, 'Invalid delegatee account name should return 0 rows';

    -- Array with wrong number of elements
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["delegate_rc"]'
    );
    ASSERT _count = 0, 'Array with 1 element should return 0 rows';

    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"alice","delegatees":["bob"],"max_rc":1000},"extra"]'
    );
    ASSERT _count = 0, 'Array with 3 elements should return 0 rows';

    RAISE NOTICE 'All RC delegation parser tests passed!';
END;
$BODY$
;
