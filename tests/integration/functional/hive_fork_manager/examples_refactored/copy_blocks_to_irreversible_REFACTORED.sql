-- REFACTORED VERSION of hived_api/copy_blocks_to_irreversible.sql
-- Demonstrates migration from manual INSERT statements to test_tools.sql functions
--
-- BEFORE: 78 lines with extensive INSERT statements
-- AFTER:  15 lines in haf_admin_test_given() - 81% reduction
--
-- Original file: hived_api/copy_blocks_to_irreversible.sql

-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Setup infrastructure
    PERFORM test.create_forks();

    -- Create irreversible blocks 1-5 (must be before accounts due to FK)
    PERFORM test.create_blocks(1, 5);

    -- Create accounts (after blocks due to FK constraint)
    PERFORM test.create_accounts();

    -- Create reversible blocks for 3 forks
    -- Fork 1: blocks 4-6
    PERFORM test.create_blocks_reversible(4, 6, 1);
    -- Fork 2: blocks 7-9
    PERFORM test.create_blocks_reversible(7, 9, 2);
    -- Fork 3: blocks 8-10 (with producer_id 6 for block 8, 7 for block 10)
    PERFORM test.create_blocks_reversible(8, 9, 3);
    -- Custom block 10 with specific producer
    INSERT INTO hafd.blocks_reversible
    VALUES (10, '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 7, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3);
END;
$BODY$;

-- Test execution remains unchanged
CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.copy_blocks_to_irreversible( 5, 8 );
END
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Note: Hashes are updated to match test_tools formula (block_num * 16 + fork_id)
    -- Block 6 from fork 1: hash = 6*16+1 = 0x61
    -- Block 7 from fork 2: hash = 7*16+2 = 0x72
    -- Block 8 from fork 3: hash = 8*16+3 = 0x83
    ASSERT NOT EXISTS (
        SELECT * FROM hafd.blocks WHERE num > 0
        EXCEPT SELECT * FROM ( VALUES
                   ( 1, '\xBADD10'::bytea, '\xCAFE10'::bytea, '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
                 , ( 2, '\xBADD20'::bytea, '\xCAFE20'::bytea, '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
                 , ( 3, '\xBADD30'::bytea, '\xCAFE30'::bytea, '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
                 , ( 4, '\xBADD40'::bytea, '\xCAFE40'::bytea, '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
                 , ( 5, '\xBADD50'::bytea, '\xCAFE50'::bytea, '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
                 , ( 6, '\xBADD61'::bytea, '\xCAFE61'::bytea, '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
                 , ( 7, '\xBADD72'::bytea, '\xCAFE72'::bytea, '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
                 , ( 8, '\xBADD83'::bytea, '\xCAFE83'::bytea, '2016-06-22 19:10:30-07'::timestamp, 6, '\x4007'::bytea, '[]'::jsonb, '\x2157'::bytea, 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
                 ) as pattern
    ) , 'Unexpected rows in hafd.blocks';
END
$BODY$;

-- NOTES:
-- 1. The data setup (haf_admin_test_given) was refactored to use test_tools functions
-- 2. Assertions were updated to match test_tools' hash generation formula (block_num * 16 + fork_id)
-- 3. We kept one custom INSERT for block 10 as it has special producer requirements
-- 4. Test behavior is preserved - same logical structure, updated to match test_tools data patterns
-- 5. Original test used custom hash values; this version uses consistent formula-based hashes
