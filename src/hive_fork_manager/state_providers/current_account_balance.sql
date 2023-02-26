
DROP FUNCTION if exists  hive.start_provider_current_account_balance;
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

    __context_id = hive.get_context_id( _context );


    IF __context_id IS NULL THEN
         RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format('DROP TABLE IF EXISTS hive.%I', __table_name);

    EXECUTE format('CREATE TABLE hive.%I 
                   (
                        account                 CHAR(16),
                        balance                 BIGINT,
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
    texcik TEXT;
BEGIN
    __context_id = hive.get_context_id( _context );

    IF __context_id IS NULL THEN
             RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format(
        'TRUNCATE TABLE hive.%s', __table_name
    );

    --RAISE WARNING '%',format('SELECT FILL_CURRENT_ACCOUNT_BALANCE_TABLE(''hive.%s'', %s, %s)',  __table_name, _first_block, _last_block);

--    EXECUTE format('SELECT FILL_CURRENT_ACCOUNT_BALANCE_TABLE(''hive.%s'', %s, %s)',  __table_name, _first_block, _last_block);
    PERFORM hive.consume_json_blocks(_first_block, _last_block, _context );


    --texcik = format('INSERT INTO hive.%I SELECT * FROM hive.current_all_accounts_balances_C(%L);', __table_name, _context);
    texcik = format('INSERT INTO hive.%I SELECT * FROM hive.current_all_accounts_balances_C(%L) ON CONFLICT DO NOTHING;', __table_name, _context);

    -- raise notice 'texcik=%', texcik;


    raise notice 'NEW_TABLE=%',
    (
        SELECT json_agg(t)
        FROM (
                SELECT *
                FROM hive.current_all_accounts_balances_C(_context)
            ) t
    );


    EXECUTE           format(texcik, __table_name);

END;
$BODY$
;






-- CREATE OR REPLACE FUNCTION FILL_CURRENT_ACCOUNT_BALANCE_TABLE(table_name TEXT, in _first_block integer, in _last_block integer)
-- RETURNS void
-- LANGUAGE plpgsql
-- VOLATILE
-- AS
-- $BODY$
-- DECLARE
-- BEGIN
--     hive.consume_json_blocks(_first_block integer,_last_block integer);
--     insert into table_name select current_all_accounts_balances_C();
-- END
-- $BODY$
-- ;


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
    __context_id = hive.get_context_id( _context );

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format( 'DROP TABLE hive.%I', __table_name );
END;
$BODY$
;
