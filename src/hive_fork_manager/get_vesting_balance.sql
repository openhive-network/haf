CREATE OR REPLACE FUNCTION hive.get_vesting_balance(_block_num INT, _current_vesting_shares BIGINT)
    RETURNS numeric
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE 
	__total_vesting_shares numeric;
	__total_vesting_fund_hive numeric;
	__hp BIGINT;
BEGIN				

	SELECT total_vesting_shares, total_vesting_fund_hive 
	INTO __total_vesting_shares, __total_vesting_fund_hive
	FROM hive.blocks_view WHERE num= _block_num;
	
    __hp := (_current_vesting_shares * __total_vesting_fund_hive) / NULLIF(__total_vesting_shares, 0);
	
	RETURN __hp;
END;
$BODY$
;


