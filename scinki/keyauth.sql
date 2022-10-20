-- Table has two columns: id INT, keyauth TEXT



CREATE OR REPLACE FUNCTION hive.update_state_provider_keyauth( _first_block hive.blocks.num%TYPE, _last_block hive.blocks.num%TYPE, _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_keyauth';




        __wartosc TEXT := 'uuauaua';
	__licznik INTEGER := -1;
    
BEGIN
    SELECT hac.id
    FROM hive.contexts hac
    WHERE hac.name = _context
        INTO __context_id;


    raise warning  'mtk update_state_provider_keyauth _first_block=%  _last_block=% __context_id=% name=%', _first_block,  _last_block, __context_id, _context;

    IF __context_id IS NULL THEN
             RAISE EXCEPTION 'No context with name %', _context;
    END IF;
    


    raise warning 'mtk a kto to wie czy +ZMIENIONY TEN PLIK !!! 2';

    

    EXECUTE format(
        'INSERT INTO hive.%s_keyauth( name )
        SELECT unnest(hive.get_account_from_keyauth_operations( ov.body )) as name
        FROM hive.%s_operations_view ov
        JOIN hive.operation_types ot ON ov.op_type_id = ot.id
        WHERE
            (ARRAY[ lower( ot.name ) ] <@ ARRAY[ ''hive::protocol::account_create_operation'' ] OR
            ARRAY[ lower( ot.name ) ] <@ ARRAY[ ''hive::protocol::account_update_operation'' ] )
            AND ov.block_num BETWEEN %s AND %s
        ON CONFLICT DO NOTHING'
        , _context, _context, _first_block, _last_block
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_key_from_entity( _account_operation TEXT , _entity TEXT)
    RETURNS TEXT[]
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BODY$
DECLARE
	    i json;
BEGIN

    __array := json_extract_path( CAST( _account_operation as json ), 'value', entity,'key_auths');

    __length := json_array_length(CAST(__array as json));

	  FOR i IN SELECT * FROM json_array_elements(cast(__array as json))
	  LOOP
	    RAISE NOTICE 'output from space %', i;
	    RAISE NOTICE 'output from space %', i->0;
		__val := i->0;
		__val := BTRIM (__val, '"');
	   __retarr := array_append(__retarr , __val);
		RAISE NOTICE '__retarr is %', __retarr;

	  END LOOP;

    raise warning  'mtk get_account_from_keyauth_operations -> returning -> %', __array;
    raise warning 'mtk with length %', __length;



    RETURN __retarr;
END;
$BODY$
;



CREATE OR REPLACE FUNCTION hive.get_account_from_keyauth_operations( _account_operation TEXT )
    RETURNS TEXT[]
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BODY$
DECLARE
    __retval TEXT := '';
	__array TEXT := '';
__length INTEGER := -1;

	    i json;
   __retarr TEXT[];

__val TEXT;
BEGIN
    raise warning  'mtk get_account_from_keyauth_operations -> getting -> %', _account_operation;

    __array := json_extract_path( CAST( _account_operation as json ), 'value', 'owner','key_auths');

    __length := json_array_length(CAST(__array as json));

	  FOR i IN SELECT * FROM json_array_elements(cast(__array as json))
	  LOOP
	    RAISE NOTICE 'output from space %', i;
	    RAISE NOTICE 'output from space %', i->0;
		__val := i->0;
		__val := BTRIM (__val, '"');
	   __retarr := array_append(__retarr , __val);
		RAISE NOTICE '__retarr is %', __retarr;

	  END LOOP;

    raise warning  'mtk get_account_from_keyauth_operations -> returning -> %', __array;
    raise warning 'mtk with length %', __length;


   __retarr := array_append(__retarr , 'elem1');
		RAISE NOTICE '__retarr 2 is %', __retarr;
   __retarr := array_append(__retarr , 'elem2');
		RAISE NOTICE '__retarr 3 is %', __retarr;

    RETURN __retarr;
END;
$BODY$
;



CREATE OR REPLACE FUNCTION hive.start_provider_keyauth( _context hive.context_name )
    RETURNS TEXT[]
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_keyauth';
    __sql TEXT = '';
BEGIN

    raise warning  'mtk start_provider_keyauth __table_name = %', __table_name;

    SELECT hac.id
    FROM hive.contexts hac
    WHERE hac.name = _context
    INTO __context_id;

    raise warning  'mtk start_provider_keyauth __context_id = %', __context_id;


    IF __context_id IS NULL THEN
         RAISE EXCEPTION 'No context with name %', _context;
    END IF;

   __sql = format( 'CREATE TABLE hive.%I(
                     id SERIAL
                   , name TEXT
                   , CONSTRAINT pk_%s PRIMARY KEY( id )
                   , CONSTRAINT uq_%s UNIQUE( name )
                   )', __table_name, __table_name,  __table_name
   );

    raise warning 'Executing->> %', __sql;

    EXECUTE __sql;


    raise warning  'mtk start_provider_keyauth After';

    RETURN ARRAY[ __table_name ];
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_state_provider_keyauth( _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_keyauth';
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
