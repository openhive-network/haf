CREATE OR REPLACE FUNCTION hive.get_context_id( _context hive.context_name )
    RETURNS hive.contexts.id%TYPE
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
BEGIN
    SELECT hac.id INTO __context_id
    FROM hive.contexts hac
    WHERE hac.name = _context;

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    RETURN __context_id;
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.calculate_operation_stable_id(
        _block_num hive.operations.block_num %TYPE,
        _trx_in_block hive.operations.trx_in_block %TYPE,
        _op_pos hive.operations.op_pos %TYPE
    ) RETURNS BIGINT LANGUAGE 'sql' IMMUTABLE AS $BODY$
SELECT (
        (_block_num::BIGINT << 36) |(
            CASE
                _trx_in_block = -1
                WHEN TRUE THEN 32768::BIGINT << 20
                ELSE _trx_in_block::BIGINT << 20
            END
        ) | (
            _op_pos::bigint & '000011111111111111111111'::"bit"::BIGINT
        )
    )
END;
$BODY$;