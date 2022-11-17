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
    ASSERT result = 0,'A31';
    result = COALESCE( ( SELECT int_or_null FROM tab_one_row ), 0 ); 
    ASSERT result = 0,'A32';
    result = COALESCE( ( SELECT int_or_null FROM tab_something_in ), 0 ); 
    ASSERT result = 3,'A33';

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

