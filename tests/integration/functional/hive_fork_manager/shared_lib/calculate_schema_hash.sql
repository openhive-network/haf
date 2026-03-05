CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
  _count INT;
BEGIN
  -- Verify the hash function runs without error and returns non-null results
  SELECT COUNT(*) INTO _count FROM hive_update.calculate_schema_hash() AS f
    WHERE f.table_schema_hash IS NOT NULL
      AND f.columns_hash IS NOT NULL
      AND f.constraints_hash IS NOT NULL
      AND f.indexes_hash IS NOT NULL;
  ASSERT _count > 0, 'calculate_schema_hash returned no rows';
  RAISE NOTICE 'calculate_schema_hash returned % rows with valid hashes', _count;

  -- Verify that removed tables are not present in the hash output
  ASSERT NOT EXISTS (
    SELECT 1 FROM hive_update.calculate_schema_hash() AS f
    WHERE f.table_name IN ('fork', 'blocks_reversible', 'transactions_reversible',
      'transactions_multisig_reversible', 'operations_reversible', 'accounts_reversible',
      'account_operations_reversible', 'applied_hardforks_reversible')
  ), 'Removed tables should not appear in schema hash';
END;
$BODY$
;
