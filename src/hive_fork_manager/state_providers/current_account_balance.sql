
TYPE 



DROP TYPE IF EXISTS hive.current_account_balance_return_type  CASCADE;
CREATE TYPE hive.current_account_balance_return_type  AS
(
--TODO 16 magic number
    account                 CHAR(16),
    balance                 BIGINT
);


CREATE OR REPLACE FUNCTION hive.start_provider_current_account_balance( _context hive.context_name )
    RETURNS TEXT[]
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_current_account_balance';
BEGIN

    __context_id = hive.get_context_id( _context_name );


    IF __context_id IS NULL THEN
         RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    
    EXECUTE format('DROP TABLE IF EXISTS hive.%I', __table_name);

    EXECUTE format('CREATE TABLE hive.%I 
                        OF 
                            hive.current_account_balance_return_type
                   (
                        PRIMARY KEY ( account )
                   )', __table_name);

    RETURN ARRAY[ __table_name ];
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.update_state_provider_current_account_balance(
    _first_block hive.blocks.num%TYPE,
    _last_block hive.blocks.num%TYPE,
    _context hive.context_name)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_current_account_balance';
BEGIN
    __context_id = hive.get_context_id( _context_name );

    IF __context_id IS NULL THEN
             RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format(
        'TRUNCATE TABLE hive.%s_current_account_balance', __table_name
    );
    EXECUTE format('FILL_CURRENT_ACCOUNT_BALANCE_TABLE(hive.%s_current_account_balance, _first_block, _last_block)',  __table_name);
END;
$BODY$
;





DROP FUNCTION IF EXISTS hive.current_all_accounts_balances_C;
CREATE OR REPLACE FUNCTION hive.current_all_accounts_balances_C();
RETURNS SETOF hive.current_account_balance_return_type
AS 'MODULE_PATHNAME', 'current_all_accounts_balances_C' LANGUAGE C;


CREATE OR REPLACE FUNCTION FILL_CURRENT_ACCOUNT_BALANCE_TABLE(TEXT table_name, in _first_block integer, in _last_block integer)
RETURNS void
LANGUAGE plpgsql
VOLATILE
AS
$BODY$
DECLARE
BEGIN
    hive.consume_json_blocks(_first_block integer,_last_block integer);
    insert into table_name select current_all_accounts_balances_C();
END
$BODY$
;


CREATE OR REPLACE FUNCTION hive.drop_state_provider_current_account_balance( _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_current_account_balance';
BEGIN
    __context_id = hive.get_context_id( _context_name );

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format( 'DROP TABLE hive.%I', __table_name );
END;
$BODY$
;
