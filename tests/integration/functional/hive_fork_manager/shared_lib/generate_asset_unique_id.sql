-- Tests for hafd.generate_asset_unique_id() C extension function
--
-- Algorithm (128-bit collision-free):
--   Bits 64-127: operation_id (64 bits)
--   Bits 32-63:  NAI (Numeric Asset Identifier) extracted from asset_symbol (32 bits)
--   Bits 0-31:   subsequent_no (32 bits)
--
-- Formula: id = (operation_id << 64) | (NAI << 32) | subsequent_no
--
-- NOTE: Only precision 0 assets are supported

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    customAssetSymbol1 hafd.asset_symbol;
    customAssetSymbol2 hafd.asset_symbol;
    asset_id hafd.asset_unique_id;
    assetInfo hive.asset_symbol_info;
BEGIN
    -- Setup: Get custom asset symbols with precision 0
    -- NAI=447575128 (from HTM tests)
    customAssetSymbol1 := (SELECT hive.asset_symbol_from_nai_string('@@447575128', 0::smallint));
    -- NAI=123456789 (another custom asset)
    customAssetSymbol2 := (SELECT hive.asset_symbol_from_nai_string('@@123456789', 0::smallint));

    -- Verify NAIs via decode
    assetInfo := (SELECT hive.decode_asset_symbol(customAssetSymbol1));
    ASSERT assetInfo.nai = 447575128, format('Custom1 NAI should be 447575128, got %s', assetInfo.nai);
    ASSERT assetInfo.precision = 0, format('Custom1 precision should be 0, got %s', assetInfo.precision);

    assetInfo := (SELECT hive.decode_asset_symbol(customAssetSymbol2));
    ASSERT assetInfo.nai = 123456789, format('Custom2 NAI should be 123456789, got %s', assetInfo.nai);
    ASSERT assetInfo.precision = 0, format('Custom2 precision should be 0, got %s', assetInfo.precision);

    -- ==========================================================================
    -- Test 1: Custom asset (NAI=447575128), operation_id=1000, subsequent_no=1
    -- Expected: (1000 << 64) | (447575128 << 32) | 1 = 18448666394246814629889
    -- ==========================================================================
    asset_id := (SELECT hafd.generate_asset_unique_id(customAssetSymbol1, 1000::BIGINT, 1::BIGINT));
    ASSERT asset_id = 18448666394246814629889::NUMERIC, format('Expected 18448666394246814629889, got %s', asset_id);
    ASSERT (asset_id % 4294967296)::BIGINT = 1, 'Lower 32 bits should be subsequent_no=1';

    -- ==========================================================================
    -- Test 2: Determinism - same inputs produce same output
    -- ==========================================================================
    ASSERT (SELECT hafd.generate_asset_unique_id(customAssetSymbol1, 1000::BIGINT, 1::BIGINT)) = 18448666394246814629889::NUMERIC,
        'Same inputs should produce same result (deterministic)';

    -- ==========================================================================
    -- Test 3: Different operation_id (op=1001, sub=1)
    -- Expected: (1001 << 64) | (447575128 << 32) | 1 = 18467113138320524181505
    -- ==========================================================================
    asset_id := (SELECT hafd.generate_asset_unique_id(customAssetSymbol1, 1001::BIGINT, 1::BIGINT));
    ASSERT asset_id = 18467113138320524181505::NUMERIC, format('Expected 18467113138320524181505, got %s', asset_id);

    -- ==========================================================================
    -- Test 4: Different subsequent_no (op=1000, sub=2)
    -- Expected: (1000 << 64) | (447575128 << 32) | 2 = 18448666394246814629890
    -- ==========================================================================
    asset_id := (SELECT hafd.generate_asset_unique_id(customAssetSymbol1, 1000::BIGINT, 2::BIGINT));
    ASSERT asset_id = 18448666394246814629890::NUMERIC, format('Expected 18448666394246814629890, got %s', asset_id);

    -- ==========================================================================
    -- Test 5: Second custom asset (NAI=123456789), op=5000, sub=10
    -- Expected: (5000 << 64) | (123456789 << 32) | 10 = 92234250611418982252554
    -- ==========================================================================
    asset_id := (SELECT hafd.generate_asset_unique_id(customAssetSymbol2, 5000::BIGINT, 10::BIGINT));
    ASSERT asset_id = 92234250611418982252554::NUMERIC, format('Expected 92234250611418982252554, got %s', asset_id);
    ASSERT (asset_id % 4294967296)::BIGINT = 10, 'Lower 32 bits should be subsequent_no=10';

    -- ==========================================================================
    -- Test 6: Zero values (op=0, sub=0)
    -- Expected: (0 << 64) | (447575128 << 32) | 0 = 1922320537263013888
    -- ==========================================================================
    asset_id := (SELECT hafd.generate_asset_unique_id(customAssetSymbol1, 0::BIGINT, 0::BIGINT));
    ASSERT asset_id = 1922320537263013888::NUMERIC, format('Expected 1922320537263013888, got %s', asset_id);

    -- ==========================================================================
    -- Test 7: Max uint32_t subsequent_no (op=1000, sub=4294967295)
    -- Expected: (1000 << 64) | (447575128 << 32) | 4294967295 = 18448666394251109597183
    -- ==========================================================================
    asset_id := (SELECT hafd.generate_asset_unique_id(customAssetSymbol1, 1000::BIGINT, 4294967295::BIGINT));
    ASSERT asset_id = 18448666394251109597183::NUMERIC, format('Expected 18448666394251109597183, got %s', asset_id);
    ASSERT (asset_id % 4294967296)::BIGINT = 4294967295, 'Lower 32 bits should be max uint32';

    -- ==========================================================================
    -- Test 8: Batch minting - sequential subsequent_no, same collection
    -- All should have same middle 32 bits (same NAI), different lower bits
    -- Using NAI=447575128:
    --   batch1: (12345 << 64) | (447575128 << 32) | 1 = 227726977910481677713409
    --   batch2: (12345 << 64) | (447575128 << 32) | 2 = 227726977910481677713410
    --   batch3: (12345 << 64) | (447575128 << 32) | 3 = 227726977910481677713411
    -- ==========================================================================
    DECLARE
        batch1 hafd.asset_unique_id;
        batch2 hafd.asset_unique_id;
        batch3 hafd.asset_unique_id;
    BEGIN
        batch1 := (SELECT hafd.generate_asset_unique_id(customAssetSymbol1, 12345::BIGINT, 1::BIGINT));
        batch2 := (SELECT hafd.generate_asset_unique_id(customAssetSymbol1, 12345::BIGINT, 2::BIGINT));
        batch3 := (SELECT hafd.generate_asset_unique_id(customAssetSymbol1, 12345::BIGINT, 3::BIGINT));

        ASSERT batch1 = 227726977910481677713409::NUMERIC, format('batch1: Expected 227726977910481677713409, got %s', batch1);
        ASSERT batch2 = 227726977910481677713410::NUMERIC, format('batch2: Expected 227726977910481677713410, got %s', batch2);
        ASSERT batch3 = 227726977910481677713411::NUMERIC, format('batch3: Expected 227726977910481677713411, got %s', batch3);

        -- All unique
        ASSERT batch1 != batch2, 'Batch IDs should be unique (1 vs 2)';
        ASSERT batch2 != batch3, 'Batch IDs should be unique (2 vs 3)';

        -- Same lower 32 bits contain subsequent_no (1, 2, 3)
        ASSERT (batch1 % 4294967296)::BIGINT = 1, 'batch1 lower 32 bits should be subsequent_no=1';
        ASSERT (batch2 % 4294967296)::BIGINT = 2, 'batch2 lower 32 bits should be subsequent_no=2';
        ASSERT (batch3 % 4294967296)::BIGINT = 3, 'batch3 lower 32 bits should be subsequent_no=3';
    END;

    -- ==========================================================================
    -- Test 9: CRITICAL - Verify NO collision between (op=1001, sub=1) and (op=1000, sub=2)
    -- With old algorithm: (1001+1) = (1000+2) = 1002 -> COLLISION!
    -- With new algorithm: different operation_ids are in separate 64-bit ranges -> NO COLLISION
    -- ==========================================================================
    DECLARE
        id_op1001_sub1 hafd.asset_unique_id;
        id_op1000_sub2 hafd.asset_unique_id;
    BEGIN
        id_op1001_sub1 := (SELECT hafd.generate_asset_unique_id(customAssetSymbol1, 1001::BIGINT, 1::BIGINT));
        id_op1000_sub2 := (SELECT hafd.generate_asset_unique_id(customAssetSymbol1, 1000::BIGINT, 2::BIGINT));

        -- These MUST be different (old algorithm made them equal!)
        ASSERT id_op1001_sub1 != id_op1000_sub2,
            format('COLLISION DETECTED! op=1001,sub=1 (%s) == op=1000,sub=2 (%s) - this should never happen!',
                   id_op1001_sub1, id_op1000_sub2);

        -- Verify expected values
        ASSERT id_op1001_sub1 = 18467113138320524181505::NUMERIC,
            format('op=1001,sub=1: Expected 18467113138320524181505, got %s', id_op1001_sub1);
        ASSERT id_op1000_sub2 = 18448666394246814629890::NUMERIC,
            format('op=1000,sub=2: Expected 18448666394246814629890, got %s', id_op1000_sub2);
    END;

END;
$BODY$
;

-- ==========================================================================
-- Error test: non-zero precision asset should raise error
-- Should raise ERRCODE_INVALID_PARAMETER_VALUE
-- ==========================================================================
CREATE OR REPLACE PROCEDURE haf_admin_test_error()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    hiveAssetSymbol hafd.asset_symbol;
    asset_id hafd.asset_unique_id;
BEGIN
    -- HIVE has precision 3, should be rejected
    hiveAssetSymbol := (SELECT hive.asset_symbol_from_nai_string('@@000000021', 3::smallint));

    -- This should raise an exception: precision is not 0
    asset_id := (SELECT hafd.generate_asset_unique_id(hiveAssetSymbol, 1000::BIGINT, 1::BIGINT));
END;
$BODY$
;
