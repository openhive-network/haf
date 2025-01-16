-- Collects all created accounts into table hive.<context_name>_accounts
-- Table has two columns: id INT, name TEXT

CREATE OR REPLACE FUNCTION hive.start_provider_accounts( _context hafd.context_name )
    RETURNS TEXT[]
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hafd.contexts.id%TYPE;
    __table_name TEXT := _context || '_accounts';
BEGIN
    SELECT hac.id
    FROM hafd.contexts hac
    WHERE hac.name = _context
    INTO __context_id;

    IF __context_id IS NULL THEN
         RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format( 'CREATE TABLE hafd.%I(
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

CREATE OR REPLACE FUNCTION hive.runtimecode_provider_accounts( _context hafd.context_name )
    RETURNS VOID
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    RETURN;
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.get_created_from_account_create_operations(IN _account_operation hafd.operation)
RETURNS TEXT
AS 'MODULE_PATHNAME', 'get_created_from_account_create_operations' LANGUAGE C;

CREATE OR REPLACE FUNCTION hive.update_state_provider_accounts( _first_block hafd.blocks.num%TYPE, _last_block hafd.blocks.num%TYPE, _context hafd.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hafd.contexts.id%TYPE;
    __table_name TEXT := _context || '_accounts';
    __context_schema TEXT;
BEGIN
    SELECT hac.id, hac.schema
    FROM hafd.contexts hac
    WHERE hac.name = _context
    INTO __context_id, __context_schema;

    IF __context_id IS NULL THEN
             RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format(
        'INSERT INTO hafd.%s_accounts( name )
        SELECT hive.get_created_from_account_create_operations( ov.body_binary ) as name
        FROM %s.operations_view ov
        JOIN hafd.operation_types ot ON ov.op_type_id = ot.id
        WHERE
            ARRAY[ lower( ot.name ) ] <@ ARRAY[ ''hive::protocol::account_created_operation'' ]
            AND ov.block_num BETWEEN %s AND %s
        ON CONFLICT DO NOTHING'
        , _context, __context_schema, _first_block, _last_block
    );
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.drop_state_provider_accounts( _context hafd.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hafd.contexts.id%TYPE;
    __table_name TEXT := _context || '_accounts';
BEGIN
    SELECT hac.id
    FROM hafd.contexts hac
    WHERE hac.name = _context
    INTO __context_id;

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format( 'DROP TABLE hafd.%I', __table_name );
END;
$BODY$
;
