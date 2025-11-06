CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    hbdAssetSymbol hafd.asset_symbol;
    hiveAssetSymbol hafd.asset_symbol;
    vestsAssetSymbol hafd.asset_symbol;
    customAssetSymbol hafd.asset_symbol;

    assetInfo hive.asset_symbol_info;
BEGIN
    hiveAssetSymbol = SELECT hive.asset_symbol_from_nai_string('@@000000021', 3::smallint));
    ASSERT(hiveAssetSymbol == 3200000035);

    hbdAssetSymbol = SELECT hive.asset_symbol_from_nai_string('@@000000013', 3::smallint);
    ASSERT(hbdAssetSymbol == 3200000003);

    vestsAssetSymbol = SELECT hive.asset_symbol_from_nai_string('@@000000037', 6::smallint);
    ASSERT(vestsAssetSymbol  == 3200000070);

    ASSERT(SELECT hive.get_paired_symbol(hiveAssetSymbol) == vestsAssetSymbol);
    ASSERT(SELECT hive.get_paired_symbol(vestsAssetSymbol) == hiveAssetSymbol);

    customAssetSymbol = SELECT hive.asset_symbol_from_nai_string('@@999867365', 3::smallint);
    ASSERT(customAssetSymbol == 3199575571);

    assetInfo = SELECT hive.decode_asset_symbol(3199575571);
    ASSERT(assetInfo == '(3,999867365,t,f)'::hive.asset_symbol_info);

    --- Now get vesting version of custom asset
    customAssetSymbol = SELECT hive.get_paired_symbol(3199575571);
    ASSERT(customAssetSymbol == 3199575603);

    assetInfo = SELECT hive.decode_asset_symbol(3199575603);
    ASSERT(assetInfo == '(3,999867379,f,f)'::hive.asset_symbol_info);

END;
$BODY$
;




