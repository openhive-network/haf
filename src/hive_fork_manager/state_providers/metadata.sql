CREATE OR REPLACE FUNCTION hive.start_provider_metadata( _context hive.context_name, _dummy_arg1 TEXT DEFAULT '')
    RETURNS TEXT[]
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_metadata';
BEGIN

    __context_id = hive.get_context_id( _context );


    IF __context_id IS NULL THEN
         RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format('DROP TABLE IF EXISTS hive.%I', __table_name);

    EXECUTE format( 'CREATE TABLE hive.%I(
                       account_id INTEGER
                     , json_metadata TEXT
                     , posting_json_metadata TEXT
                   , PRIMARY KEY ( account_id )
                   )', __table_name);
    RETURN ARRAY[ __table_name ];
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.update_state_provider_metadata(
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
    __table_name TEXT := _context || '_metadata';
BEGIN
    __context_id = hive.get_context_id( _context );

    IF __context_id IS NULL THEN
             RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format(
                'INSERT INTO hive.%s_metadata
                 SELECT accounts_view.id, json_metadata, posting_json_metadata FROM (
                    SELECT (hive.get_metadata( ov.body )).*               
                    FROM hive.%s_operations_view ov  
                    WHERE                               
                            hive.is_metadata_operation(ov.body)   
                        AND
                            ov.block_num BETWEEN %s AND %s
                    ) as get_metadata 
                    JOIN 
                        hive.accounts_view accounts_view 
                    ON accounts_view.name = get_metadata.account_name'
            , _context, _context, _first_block, _last_block
            );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_state_provider_metadata( _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_metadata';
BEGIN
    __context_id = hive.get_context_id( _context );

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format( 'DROP TABLE hive.%I', __table_name );
END;
$BODY$
;
