WITH accounts_with_pow2 AS (
    SELECT block_num, body->'value'->'work'->'value'->'input'->'worker_account' as worker_account FROM hive.operations_view o join hive.operation_types a ON o.op_type_id = a.id WHERE a.name = 'hive::protocol::pow2_operation'
),

including_account_origin_block_num AS (
    SELECT ap.block_num as op_block_num, name, a.block_num as org_block_num FROM accounts_with_pow2 ap JOIN hive.accounts a ON REPLACE(ap.worker_account::TEXT, '"', '') = a.name
)
SELECT * FROM including_account_origin_block_num WHERE op_block_num = org_block_num;

