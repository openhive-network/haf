DROP FUNCTION IF EXISTS test_given; CREATE FUNCTION test_given() RETURNS void LANGUAGE 'plpgsql' VOLATILE AS  $BODY$
DECLARE 
    result INT;
    bresult BOOLean;
    bresult2 BOOLean;
BEGIN


    CREATE TABLE tab_empty(
      id integer,
      int_or_null integer,
      b bool NOT NULL,
      CONSTRAINT pk_tab_empty PRIMARY KEY ( id )
    );

    CREATE TABLE tab_one_row(
      id integer,
      int_or_null integer,
      b bool NOT NULL,
      CONSTRAINT pk_tab_one_row PRIMARY KEY ( id )
    );
    INSERT INTO tab_one_row VALUES(1,NULL, FALSE) ON CONFLICT DO NOTHING;


    CREATE TABLE tab_something_in(
      id integer,
      int_or_null integer,
      b bool NOT NULL,
      CONSTRAINT pk_tab_something_in PRIMARY KEY ( id )
    );
    INSERT INTO tab_something_in VALUES(1,3, TRUE) ON CONFLICT DO NOTHING;



    SELECT int_or_null INTO result FROM tab_empty; 
    ASSERT result is NULL,'A1';

    SELECT int_or_null INTO result FROM tab_one_row; 
    ASSERT result is NULL,'A2';

    SELECT int_or_null INTO result FROM tab_something_in; 
    ASSERT result = 3, 'A3';


    result = COALESCE( ( SELECT int_or_null FROM tab_empty ), 0 ); 
    ASSERT result = 0,'A3a';
    result = COALESCE( ( SELECT int_or_null FROM tab_one_row ), 0 ); 
    ASSERT result = 0,'A3b';
    result = COALESCE( ( SELECT int_or_null FROM tab_something_in ), 0 ); 
    ASSERT result = 3,'A3c';

    bresult = COALESCE((SELECT b FROM tab_empty),  FALSE);
    SELECT COALESCE((SELECT b FROM tab_empty),  FALSE) INTO bresult2;
    ASSERT bresult = bresult2;
    ASSERT bresult is FALSE, 'A4';

    bresult = COALESCE((SELECT b FROM tab_one_row),  FALSE);
    SELECT COALESCE((SELECT b FROM tab_one_row),  FALSE) INTO bresult2;
    ASSERT bresult = bresult2;
    ASSERT bresult is FALSE, 'A5';

    bresult = COALESCE((SELECT b FROM tab_something_in),  TRUE);
    SELECT COALESCE((SELECT b FROM tab_something_in),  TRUE) INTO bresult2;
    ASSERT bresult = bresult2;
    ASSERT bresult is TRUE, 'A6';


    -- multiple assignment like this
    --SELECT int_or_null, b INTO result, bresult FROM tab_empty;    
    -- split into two 
    SELECT int_or_null FROM tab_empty  INTO result ; 
    SELECT COALESCE((SELECT b FROM tab_empty),  FALSE) INTO bresult;
    ASSERT result is null, 'A7';
    ASSERT bresult = FALSE, 'A8';

    SELECT int_or_null FROM tab_one_row  INTO result ; 
    SELECT COALESCE((SELECT b FROM tab_one_row),  FALSE) INTO bresult;
    ASSERT result is null, 'A9';
    ASSERT bresult = FALSE, 'A10';

    SELECT int_or_null FROM tab_something_in  INTO result ; 
    SELECT COALESCE((SELECT b FROM tab_something_in),  FALSE) INTO bresult;
    ASSERT result = 3, 'A11';
    ASSERT bresult = TRUE, 'A12';




    INSERT INTO tab_empty (id,  b) VALUES (1,  TRUE) 
    ON CONFLICT (id) DO UPDATE SET int_or_null = 15;
    Raise Notice '>>>>%', (SELECT array_agg(t) FROM (SELECT * FROM tab_empty)t);

    INSERT INTO tab_empty (id, int_or_null, b) VALUES (1, 15, TRUE) 
    ON CONFLICT (id) DO UPDATE SET int_or_null = 15;
    Raise Notice '>>>>%', (SELECT array_agg(t) FROM (SELECT * FROM tab_empty)t);


    --INSERT INTO hive.irreversible_data_renamed (id, is_dirty) VALUES (1, flag) 
    --ON CONFLICT (id) DO UPDATE SET is_dirty = flag;

END;
$BODY$
;

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
DECLARE 
BEGIN
END
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN


END
$BODY$
;

