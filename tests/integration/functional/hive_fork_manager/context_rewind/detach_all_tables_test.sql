
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    CREATE SCHEMA B;
    PERFORM hive.context_create( 'context', 'a' );
    CREATE TABLE A.table1(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT) INHERITS( a.context );
    CREATE TABLE B.table2(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT) INHERITS( a.context );
    PERFORM hive.context_create( 'context2', 'a' );
    CREATE TABLE A.table3(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT) INHERITS( a.context2 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_detach( 'context' );
    PERFORM hive.context_next_block( 'context' );
    PERFORM hive.context_next_block( 'context2' );
    INSERT INTO A.table1( smth, name ) VALUES (1, 'abc' );
    INSERT INTO B.table2( smth, name ) VALUES (1, 'abc' );
    INSERT INTO A.table3( smth, name ) VALUES (1, 'abc' );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT * FROM hafd.contexts hc JOIN hafd.contexts_attachment hca ON hca.context_id = hc.id WHERE hc.name = 'context' AND hca.is_attached = FALSE ), 'Context is not marked as attached';
    ASSERT EXISTS ( SELECT * FROM hafd.registered_tables WHERE origin_table_schema='a' AND origin_table_name='table1' ), 'Attach flag is not set to false';
    ASSERT NOT EXISTS ( SELECT * FROM hafd.shadow_a_table1 ), 'Trigger iserted something into shadow table';
    ASSERT NOT EXISTS ( SELECT * FROM hafd.shadow_b_table2 ), 'Trigger iserted something into shadow table';

    ASSERT EXISTS ( SELECT * FROM hafd.contexts hc JOIN hafd.contexts_attachment hca ON hca.context_id = hc.id WHERE hc.name = 'context2' AND hca.is_attached = TRUE ), 'Context2 is not marked as attached';
    ASSERT EXISTS ( SELECT * FROM hafd.shadow_a_table3 ), 'Trigger did not isert something into shadow table';
END
$BODY$
;




