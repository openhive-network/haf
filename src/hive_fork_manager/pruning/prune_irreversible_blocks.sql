CREATE OR REPLACE FUNCTION hive.prune_blocks_data()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __upper_bound_block_num INTEGER := NULL;
BEGIN
    SELECT min(irreversible_block)
    INTO __upper_bound_block_num
    FROM hafd.contexts hc;

    --TODO(mickiewicz@syncad.com): when block is removed account needs to be set created_block to NULL
    --TODO(mickiewicz@syncad.com): too much times the same schema occur: all hafd blocks tables are modified
    --                   need to add some container to make it automatically (table with oid of hafd tables ?)
    --                   without repeating tables names each time
    DELETE FROM hafd.account_operations har
        USING hafd.operations hor
    WHERE
        har.operation_id = hor.id
        AND ( hafd.operation_id_to_block_num(hor.id) < __upper_bound_block_num)
    ;

    DELETE FROM hafd.applied_hardforks hjr
    WHERE hjr.block_num < __upper_bound_block_num
    ;

    DELETE FROM hafd.operations hor
    WHERE hafd.operation_id_to_block_num(hor.id) < __upper_bound_block_num;
    ;


    DELETE FROM hafd.transactions_multisig htmr
        USING hafd.transactions htr
    WHERE
      htr.trx_hash = htmr.trx_hash
      AND ( htr.block_num < __upper_bound_block_num )
    ;

    DELETE FROM hafd.transactions htr
    WHERE  htr.block_num < __upper_bound_block_num
    ;

    UPDATE hafd.accounts harss
    SET har.block_num = NULL
    WHERE har.block_num < __upper_bound_block_num
    ;

    DELETE FROM hafd.blocks hbr
    WHERE hbr.num < __upper_bound_block_num
    ;

END;
$BODY$
;