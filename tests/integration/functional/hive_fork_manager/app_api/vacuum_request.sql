CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_impersonal_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_request_table_vacuum('a.table1');
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
   ASSERT
       (SELECT COUNT(*) FROM hafd.vacuum_requests WHERE table_name = 'a.table1' ) = 1
        , 'a.table1 wrong number of requests';

   ASSERT
       (SELECT status FROM hafd.vacuum_requests WHERE table_name = 'a.table1' ) = 'requested'
       , 'a.table1 status != requested';
END;
$BODY$
;
