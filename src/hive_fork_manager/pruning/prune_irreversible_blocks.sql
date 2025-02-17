CREATE OR REPLACE FUNCTION hive.prune_blocks_data( _tail_size INTEGER  = 0 )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __upper_bound_block_num INTEGER;
    __max_block_num INTEGER;
BEGIN
    IF _tail_size < 0 THEN
        RAISE EXCEPTION 'Blocks tail cannot be lower than 0  but is %', _tail_size;
    END IF;

    SELECT consistent_block INTO __max_block_num FROM hafd.irreversible_data;

    SELECT COALESCE( min(irreversible_block), __max_block_num )
    INTO __upper_bound_block_num
    FROM hafd.contexts hc;

    IF __upper_bound_block_num <= _tail_size THEN
        RETURN;
    END IF;

    __upper_bound_block_num = __upper_bound_block_num - _tail_size;

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
    WHERE hafd.operation_id_to_block_num(hor.id) < __upper_bound_block_num
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

    UPDATE hafd.accounts ha
    SET block_num = NULL
    WHERE ha.block_num < __upper_bound_block_num
    ;

    DELETE FROM hafd.blocks hbr
    WHERE hbr.num < __upper_bound_block_num
    ;

END;
$BODY$
;