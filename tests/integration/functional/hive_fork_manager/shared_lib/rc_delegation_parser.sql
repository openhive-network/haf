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

    -- ==========================================================================
    -- TEST: a list is applied all or nothing (hived: generic_custom_operation_interpreter.hpp,
    -- apply_operations validates every inner op before applying any, inside one undo session;
    -- hive_evaluator.cpp custom_json_evaluator::do_apply swallows the failure outside is_in_control())
    -- ==========================================================================

    -- An unknown op name fails custom_op_from_variant for the whole list
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '[["other_op",{"some":"data"}],["delegate_rc",{"from":"alice","delegatees":["bob"],"max_rc":1000}]]'
    );
    ASSERT _count = 0, 'Unknown op in a list should return 0 rows, got ' || _count;

    -- One invalid op (self-delegation) discards the valid one
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '[["delegate_rc",{"from":"alice","delegatees":["alice"],"max_rc":1000}],["delegate_rc",{"from":"bob","delegatees":["carol"],"max_rc":2000}]]'
    );
    ASSERT _count = 0, 'Invalid op in a list should return 0 rows, got ' || _count;

    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '[["delegate_rc",{"from":"bob","delegatees":["carol"],"max_rc":2000}],["delegate_rc",{"from":"alice","delegatees":["bob"],"max_rc":-1}]]'
    );
    ASSERT _count = 0, 'Invalid last op in a list should return 0 rows, got ' || _count;

    -- An incomplete element leaves a default delegate_rc_operation, which fails validation
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '[["delegate_rc",{"from":"bob","delegatees":["carol"],"max_rc":2000}],["delegate_rc"]]'
    );
    ASSERT _count = 0, 'Incomplete element in a list should return 0 rows, got ' || _count;

    -- An element that is neither array nor object fails is_object()
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '[["delegate_rc",{"from":"bob","delegatees":["carol"],"max_rc":2000}],"delegate_rc"]'
    );
    ASSERT _count = 0, 'Scalar element in a list should return 0 rows, got ' || _count;

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

    -- Array with fewer than 2 elements (hived: custom_op_from_variant ignores it, leaving a default
    -- delegate_rc_operation that apply_operations rejects in operation_validate)
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["delegate_rc"]'
    );
    ASSERT _count = 0, 'Array with 1 element should return 0 rows';

    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation('[]');
    ASSERT _count = 0, 'Empty array should return 0 rows';

    -- ==========================================================================
    -- TEST: dangling array elements (hived: generic_custom_operation_interpreter.hpp,
    -- custom_op_from_variant uses the first two elements outside is_in_control() and logs
    -- "Dangling elements of custom operation ignored")
    -- ==========================================================================

    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"alice","delegatees":["bob"],"max_rc":1000},"x"]'
    );
    ASSERT _count = 1, 'Array with 3 elements should return 1 row, got ' || _count;

    SELECT * INTO _result FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"alice","delegatees":["bob"],"max_rc":1000},"x"]'
    );
    ASSERT _result.from_account = 'alice', 'from_account should be alice';
    ASSERT _result.to_account = 'bob', 'to_account should be bob';
    ASSERT _result.max_rc = 1000, 'max_rc should be 1000';

    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '[[0,{"from":"alice","delegatees":["bob"],"max_rc":1000},1,{}],["delegate_rc",{"from":"alice","delegatees":["carol"],"max_rc":2000},null]]'
    );
    ASSERT _count = 2, 'Dangling elements in a list should return 2 rows, got ' || _count;

    -- The dangling elements do not make an invalid op valid
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '["delegate_rc",{"from":"alice","delegatees":["alice"],"max_rc":1000},"x"]'
    );
    ASSERT _count = 0, 'Invalid op with dangling elements should return 0 rows, got ' || _count;

    -- ==========================================================================
    -- TEST: object serialization {"type","value"} (hived: generic_custom_operation_interpreter.hpp,
    -- custom_op_from_variant takes an integer type via as_int64, or a name from the to_tag map built
    -- by get_custom_operation_name, i.e. trim_typename_namespace of the type: "delegate_rc_operation";
    -- extra keys are ignored outside is_in_control())
    -- ==========================================================================

    SELECT * INTO _result FROM hive.parse_rc_delegation(
        '{"type":"delegate_rc_operation","value":{"from":"alice","delegatees":["bob"],"max_rc":1000}}'
    );
    ASSERT _result.from_account = 'alice', 'Object form by name: from_account should be alice';
    ASSERT _result.to_account = 'bob', 'Object form by name: to_account should be bob';
    ASSERT _result.max_rc = 1000, 'Object form by name: max_rc should be 1000';

    SELECT * INTO _result FROM hive.parse_rc_delegation(
        '{"type":0,"value":{"from":"alice","delegatees":["bob"],"max_rc":1000}}'
    );
    ASSERT _result.from_account = 'alice', 'Object form by index: from_account should be alice';
    ASSERT _result.to_account = 'bob', 'Object form by index: to_account should be bob';
    ASSERT _result.max_rc = 1000, 'Object form by index: max_rc should be 1000';

    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '{"type":"delegate_rc_operation","value":{"from":"alice","delegatees":["bob"],"max_rc":1000},"extra":1}'
    );
    ASSERT _count = 1, 'Object form with an extra key should return 1 row, got ' || _count;

    -- Object form inside a list (the list is recognised by its first element being an array)
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '[["delegate_rc",{"from":"alice","delegatees":["bob"],"max_rc":1000}],{"type":"delegate_rc_operation","value":{"from":"alice","delegatees":["carol","dave"],"max_rc":2000}}]'
    );
    ASSERT _count = 3, 'Object form in a list should return 3 rows, got ' || _count;

    -- A first element that is an object does not make a list; it is read as a legacy pair and fails
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '[{"type":0,"value":{"from":"alice","delegatees":["bob"],"max_rc":1000}},["delegate_rc",{"from":"alice","delegatees":["carol"],"max_rc":2000}]]'
    );
    ASSERT _count = 0, 'List starting with an object should return 0 rows, got ' || _count;

    -- The legacy name is not in the to_tag map
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '{"type":"delegate_rc","value":{"from":"alice","delegatees":["bob"],"max_rc":1000}}'
    );
    ASSERT _count = 0, 'Object form with the legacy name should return 0 rows, got ' || _count;

    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '{"type":1,"value":{"from":"alice","delegatees":["bob"],"max_rc":1000}}'
    );
    ASSERT _count = 0, 'Object form with index 1 should return 0 rows, got ' || _count;

    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '{"type":"delegate_rc_operation"}'
    );
    ASSERT _count = 0, 'Object form without value should return 0 rows, got ' || _count;

    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '{"value":{"from":"alice","delegatees":["bob"],"max_rc":1000}}'
    );
    ASSERT _count = 0, 'Object form without type should return 0 rows, got ' || _count;

    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation(
        '{"type":0,"value":{"from":"alice","delegatees":["alice"],"max_rc":1000}}'
    );
    ASSERT _count = 0, 'Object form with self-delegation should return 0 rows, got ' || _count;

    -- A scalar payload is neither serialization
    SELECT COUNT(*) INTO _count FROM hive.parse_rc_delegation('"delegate_rc"');
    ASSERT _count = 0, 'Scalar payload should return 0 rows, got ' || _count;

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
