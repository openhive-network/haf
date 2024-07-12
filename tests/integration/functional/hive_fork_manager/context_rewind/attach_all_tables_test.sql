
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    CREATE SCHEMA B;
    PERFORM hive.context_create( 'context', 'a' );
    CREATE TABLE A.table1(id  SERIAL PRIMARY KEY, smth INTEGER, name hive.ctext) INHERITS( a.context );
    CREATE TABLE B.table2(id  SERIAL PRIMARY KEY, smth INTEGER, name hive.ctext) INHERITS( a.context );
    PERFORM hive.context_create( 'context2', 'a' );
    CREATE TABLE A.table3(id  SERIAL PRIMARY KEY, smth INTEGER, name hive.ctext) INHERITS( a.context2 );

    PERFORM hive.context_next_block( 'context' );
    PERFORM hive.context_next_block( 'context2' );

    PERFORM hive.context_detach( 'context' );
    PERFORM hive.context_detach( 'context2' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_attach( 'context', 100 );
    PERFORM hive.context_next_block( 'context' );
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
    ASSERT EXISTS ( SELECT * FROM hive.contexts hc JOIN hive.contexts_attachment hca ON hca.context_id=hc.id WHERE hc.name='context' AND hca.is_attached = TRUE ), 'Attach flag is still not set';
    ASSERT EXISTS ( SELECT * FROM hive.shadow_a_table1 ), 'Trigger inserted something into shadow table1';
    ASSERT EXISTS ( SELECT * FROM hive.shadow_b_table2  ), 'Trigger inserted something into shadow table2';

    ASSERT EXISTS ( SELECT * FROM hive.contexts hc JOIN hive.contexts_attachment hca ON hca.context_id=hc.id WHERE hc.name='context2' AND hca.is_attached = FALSE ), 'Attach flag is still set';
    ASSERT NOT EXISTS ( SELECT * FROM hive.shadow_a_table3 WHERE hive_block_num = 101 ), 'Trigger did not insert something into shadow table3';
END
$BODY$
;




