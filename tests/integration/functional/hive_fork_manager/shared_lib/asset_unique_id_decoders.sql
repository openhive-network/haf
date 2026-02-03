-- Tests for hafd.asset_unique_id_to_* decoder functions
--
-- Algorithm (128-bit):
--   Bits 64-127: operation_id (64 bits)
--   Bits 32-63:  NAI (Numeric Asset Identifier) (32 bits)
--   Bits 0-31:   subsequent_no (32 bits)
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
    decoded_op_id BIGINT;
    decoded_symbol hafd.asset_symbol;
    decoded_sub_no BIGINT;
    assetInfo hive.asset_symbol_info;
BEGIN
    -- Setup: Get custom asset symbols with precision 0
    customAssetSymbol1 := (SELECT hive.asset_symbol_from_nai_string('@@447575128', 0::smallint));
    customAssetSymbol2 := (SELECT hive.asset_symbol_from_nai_string('@@123456789', 0::smallint));

    -- ==========================================================================
    -- Test 1: Round-trip with custom asset
    -- Generate ID and verify all components can be decoded correctly
    -- ==========================================================================
    asset_id := (SELECT hafd.generate_asset_unique_id(customAssetSymbol1, 1000::BIGINT, 1::BIGINT));

    decoded_op_id := (SELECT hafd.asset_unique_id_to_operation_id(asset_id));
    ASSERT decoded_op_id = 1000, format('operation_id: Expected 1000, got %s', decoded_op_id);

    decoded_symbol := (SELECT hafd.asset_unique_id_to_asset_symbol(asset_id));
    assetInfo := (SELECT hive.decode_asset_symbol(decoded_symbol));
    ASSERT assetInfo.nai = 447575128, format('NAI: Expected 447575128, got %s', assetInfo.nai);
    ASSERT assetInfo.precision = 0, format('precision: Expected 0, got %s', assetInfo.precision);

    decoded_sub_no := (SELECT hafd.asset_unique_id_to_subsequent_no(asset_id));
    ASSERT decoded_sub_no = 1, format('subsequent_no: Expected 1, got %s', decoded_sub_no);

    -- ==========================================================================
    -- Test 2: Round-trip with second custom asset and larger values
    -- ==========================================================================
    asset_id := (SELECT hafd.generate_asset_unique_id(customAssetSymbol2, 5000::BIGINT, 10::BIGINT));

    decoded_op_id := (SELECT hafd.asset_unique_id_to_operation_id(asset_id));
    ASSERT decoded_op_id = 5000, format('operation_id: Expected 5000, got %s', decoded_op_id);

    decoded_symbol := (SELECT hafd.asset_unique_id_to_asset_symbol(asset_id));
    assetInfo := (SELECT hive.decode_asset_symbol(decoded_symbol));
    ASSERT assetInfo.nai = 123456789, format('NAI: Expected 123456789, got %s', assetInfo.nai);

    decoded_sub_no := (SELECT hafd.asset_unique_id_to_subsequent_no(asset_id));
    ASSERT decoded_sub_no = 10, format('subsequent_no: Expected 10, got %s', decoded_sub_no);

    -- ==========================================================================
    -- Test 3: Zero values
    -- ==========================================================================
    asset_id := (SELECT hafd.generate_asset_unique_id(customAssetSymbol1, 0::BIGINT, 0::BIGINT));

    decoded_op_id := (SELECT hafd.asset_unique_id_to_operation_id(asset_id));
    ASSERT decoded_op_id = 0, format('operation_id: Expected 0, got %s', decoded_op_id);

    decoded_sub_no := (SELECT hafd.asset_unique_id_to_subsequent_no(asset_id));
    ASSERT decoded_sub_no = 0, format('subsequent_no: Expected 0, got %s', decoded_sub_no);

    -- ==========================================================================
    -- Test 4: Maximum uint32 subsequent_no
    -- ==========================================================================
    asset_id := (SELECT hafd.generate_asset_unique_id(customAssetSymbol1, 1000::BIGINT, 4294967295::BIGINT));

    decoded_sub_no := (SELECT hafd.asset_unique_id_to_subsequent_no(asset_id));
    ASSERT decoded_sub_no = 4294967295, format('subsequent_no: Expected 4294967295, got %s', decoded_sub_no);

    -- ==========================================================================
    -- Test 5: Large operation_id (max positive BIGINT)
    -- ==========================================================================
    asset_id := (SELECT hafd.generate_asset_unique_id(customAssetSymbol1, 9223372036854775807::BIGINT, 1::BIGINT));

    decoded_op_id := (SELECT hafd.asset_unique_id_to_operation_id(asset_id));
    ASSERT decoded_op_id = 9223372036854775807, format('operation_id: Expected max BIGINT, got %s', decoded_op_id);

    -- ==========================================================================
    -- Test 6: Batch verification - ensure unique IDs decode back correctly
    -- ==========================================================================
    DECLARE
        batch1 hafd.asset_unique_id;
        batch2 hafd.asset_unique_id;
        batch3 hafd.asset_unique_id;
    BEGIN
        batch1 := (SELECT hafd.generate_asset_unique_id(customAssetSymbol1, 12345::BIGINT, 1::BIGINT));
        batch2 := (SELECT hafd.generate_asset_unique_id(customAssetSymbol1, 12345::BIGINT, 2::BIGINT));
        batch3 := (SELECT hafd.generate_asset_unique_id(customAssetSymbol1, 12345::BIGINT, 3::BIGINT));

        -- All should have same operation_id
        ASSERT (SELECT hafd.asset_unique_id_to_operation_id(batch1)) = 12345, 'batch1 op_id';
        ASSERT (SELECT hafd.asset_unique_id_to_operation_id(batch2)) = 12345, 'batch2 op_id';
        ASSERT (SELECT hafd.asset_unique_id_to_operation_id(batch3)) = 12345, 'batch3 op_id';

        -- All should have same NAI
        ASSERT (SELECT (hive.decode_asset_symbol(hafd.asset_unique_id_to_asset_symbol(batch1))).nai) = 447575128, 'batch1 NAI';
        ASSERT (SELECT (hive.decode_asset_symbol(hafd.asset_unique_id_to_asset_symbol(batch2))).nai) = 447575128, 'batch2 NAI';
        ASSERT (SELECT (hive.decode_asset_symbol(hafd.asset_unique_id_to_asset_symbol(batch3))).nai) = 447575128, 'batch3 NAI';

        -- Different subsequent_no values
        ASSERT (SELECT hafd.asset_unique_id_to_subsequent_no(batch1)) = 1, 'batch1 sub_no';
        ASSERT (SELECT hafd.asset_unique_id_to_subsequent_no(batch2)) = 2, 'batch2 sub_no';
        ASSERT (SELECT hafd.asset_unique_id_to_subsequent_no(batch3)) = 3, 'batch3 sub_no';
    END;

    -- ==========================================================================
    -- Test 7: Decode a known value directly (without generating)
    -- id = 18448666394246814629889 = (1000 << 64) | (447575128 << 32) | 1
    -- ==========================================================================
    asset_id := 18448666394246814629889::hafd.asset_unique_id;

    decoded_op_id := (SELECT hafd.asset_unique_id_to_operation_id(asset_id));
    ASSERT decoded_op_id = 1000, format('Direct decode operation_id: Expected 1000, got %s', decoded_op_id);

    decoded_symbol := (SELECT hafd.asset_unique_id_to_asset_symbol(asset_id));
    assetInfo := (SELECT hive.decode_asset_symbol(decoded_symbol));
    ASSERT assetInfo.nai = 447575128, format('Direct decode NAI: Expected 447575128, got %s', assetInfo.nai);

    decoded_sub_no := (SELECT hafd.asset_unique_id_to_subsequent_no(asset_id));
    ASSERT decoded_sub_no = 1, format('Direct decode subsequent_no: Expected 1, got %s', decoded_sub_no);

END;
$BODY$
;
