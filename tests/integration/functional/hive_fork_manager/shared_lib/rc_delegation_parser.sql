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

    -- ==========================================================================
    -- TEST: numeric operation index (hived: generic_custom_operation_interpreter.hpp,
    -- custom_op_from_variant accepts a uint64 index into rc_custom_operation, where
    -- delegate_rc_operation is the only alternative, index 0)
    -- ==========================================================================

    -- Mainnet block 102,303,329
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '[0,{"from":"jjerryhan","delegatees":["upyourpostap"],"max_rc":2000000000000}]'
    );
    ASSERT _count = 1, 'Numeric index 0 should return 1 row, got ' || _count;

    SELECT * INTO _result FROM hive.parse_rc_delegation(
        '[0,{"from":"jjerryhan","delegatees":["upyourpostap"],"max_rc":2000000000000}]'
    );
    ASSERT _result.from_account = 'jjerryhan', 'from_account should be jjerryhan';
    ASSERT _result.to_account = 'upyourpostap', 'to_account should be upyourpostap';
    ASSERT _result.max_rc = 2000000000000, 'max_rc should be 2000000000000';

    -- Numeric index in the multiple operations format
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '[[0,{"from":"alice","delegatees":["bob"],"max_rc":1000}],["delegate_rc",{"from":"alice","delegatees":["carol"],"max_rc":2000}]]'
    );
    ASSERT _count = 2, 'Numeric index in a list should return 2 rows, got ' || _count;

    -- Index out of rc_custom_operation range (static_variant rejects the tag)
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '[1,{"from":"alice","delegatees":["bob"],"max_rc":1000}]'
    );
    ASSERT _count = 0, 'Numeric index 1 should return 0 rows, got ' || _count;

    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '[[1,{"from":"alice","delegatees":["bob"],"max_rc":1000}]]'
    );
    ASSERT _count = 0, 'Numeric index 1 in a list should return 0 rows, got ' || _count;

    -- Negative numbers are int64, not uint64, so hived looks them up as names and fails
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '[-1,{"from":"alice","delegatees":["bob"],"max_rc":1000}]'
    );
    ASSERT _count = 0, 'Numeric index -1 should return 0 rows, got ' || _count;

    -- The index as a string is not a legacy operation name
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["0",{"from":"alice","delegatees":["bob"],"max_rc":1000}]'
    );
    ASSERT _count = 0, 'String "0" should return 0 rows, got ' || _count;

    -- ==========================================================================
    -- TEST: account name conversion (hived: hive_evaluator.cpp custom_json_evaluator
    -- disables truncation_controller verification outside is_in_control(), so
    -- fixed_string<16> (account_name_type, fixed_string.hpp) keeps the first 16 bytes)
    -- ==========================================================================

    -- Mainnet block 70,000,531: 17th character dropped
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"deepresearch","delegatees":["patent-wynalazek\r"],"max_rc":18022221811}]'
    );
    ASSERT _count = 1, 'Overlong delegatee should be truncated and return 1 row, got ' || _count;

    SELECT * INTO _result FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"deepresearch","delegatees":["patent-wynalazek\r"],"max_rc":18022221811}]'
    );
    ASSERT _result.from_account = 'deepresearch', 'from_account should be deepresearch';
    ASSERT _result.to_account = 'patent-wynalazek', 'to_account should be patent-wynalazek, got ' || _result.to_account;
    ASSERT _result.max_rc = 18022221811, 'max_rc should be 18022221811';

    -- from is converted the same way
    SELECT * INTO _result FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"patent-wynalazekxyz","delegatees":["bob"],"max_rc":1000}]'
    );
    ASSERT _result.from_account = 'patent-wynalazek', 'from_account should be patent-wynalazek, got ' || _result.from_account;

    -- Names collapsing to the same 16 bytes are one delegatee (flat_set)
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"deepresearch","delegatees":["patent-wynalazek","patent-wynalazek\r"],"max_rc":1000}]'
    );
    ASSERT _count = 1, 'Delegatees equal after truncation should return 1 row, got ' || _count;

    -- Invalid character within the first 16 bytes is not truncated away
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"deepresearch","delegatees":["patent-wynalaze\r"],"max_rc":1000}]'
    );
    ASSERT _count = 0, 'Invalid character in a 16 byte name should return 0 rows, got ' || _count;

    -- The truncated name is still validated (ends with a dash)
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"deepresearch","delegatees":["patent-wynalaze-k"],"max_rc":1000}]'
    );
    ASSERT _count = 0, 'Truncated name that is invalid should return 0 rows, got ' || _count;

    -- Self-delegation is checked after truncation
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"patent-wynalazek","delegatees":["patent-wynalazek\r"],"max_rc":1000}]'
    );
    ASSERT _count = 0, 'Self-delegation after truncation should return 0 rows, got ' || _count;

    RAISE NOTICE 'All RC delegation parser tests passed!';
END;
$BODY$
;
