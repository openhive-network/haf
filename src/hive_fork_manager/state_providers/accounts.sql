-- Collects all created accounts into table hive.<context_name>_accounts
-- Table has two columns: id INT, name TEXT

CREATE OR REPLACE FUNCTION hive.start_provider_accounts( _context hive.context_name )
    RETURNS TEXT[]
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_accounts';
BEGIN
    SELECT hac.id
    FROM hive.contexts hac
    WHERE hac.name = _context
    INTO __context_id;

    IF __context_id IS NULL THEN
         RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format( 'CREATE TABLE hive.%I(
                      id SERIAL
                    , name TEXT
                    , CONSTRAINT pk_%s PRIMARY KEY( id )
                    , CONSTRAINT uq_%s UNIQUE( name )
                    )', __table_name, __table_name,  __table_name
    );

    RETURN ARRAY[ __table_name ];
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_account_from_accounts_operations(IN _account_operation hive.operation)
RETURNS TEXT
AS 'MODULE_PATHNAME', 'get_account_from_accounts_operations' LANGUAGE C;

CREATE OR REPLACE FUNCTION hive.update_state_provider_accounts( _first_block hive.blocks.num%TYPE, _last_block hive.blocks.num%TYPE, _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_accounts';
BEGIN
    SELECT hac.id
    FROM hive.contexts hac
    WHERE hac.name = _context
        INTO __context_id;

    IF __context_id IS NULL THEN
             RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format(
        'INSERT INTO hive.%s_accounts( name )
        SELECT hive.get_account_from_accounts_operations( ov.body ) as name
        FROM hive.%s_operations_view ov
        JOIN hive.operation_types ot ON ov.op_type_id = ot.id
        WHERE
            ARRAY[ lower( ot.name ) ] <@ ARRAY[ ''hive::protocol::account_created_operation'' ]
            AND ov.block_num BETWEEN %s AND %s
        ON CONFLICT DO NOTHING'
        , _context, _context, _first_block, _last_block
    );
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.drop_state_provider_accounts( _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_accounts';
BEGIN
    SELECT hac.id
    FROM hive.contexts hac
    WHERE hac.name = _context
    INTO __context_id;

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format( 'DROP TABLE hive.%I', __table_name );
END;
$BODY$
;
