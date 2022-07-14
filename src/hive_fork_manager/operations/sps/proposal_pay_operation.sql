CREATE TYPE hive.proposal_pay_operation AS (
  proposal_id int8, -- uint32_t: 4 bytes, but unsigned (int8)
  receiver hive.account_name_type,
  payer hive.account_name_type,
  payment hive.asset,
  trx_id hive.transaction_id_type,
  op_in_trx int4 -- uint16_t: 2 bytes, but unsigned (int4)
);

SELECT _variant.create_cast_in( 'hive.proposal_pay_operation' );
SELECT _variant.create_cast_out( 'hive.proposal_pay_operation' );
