
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context', 'a' );
    CREATE TABLE table1( id INTEGER PRIMARY KEY, smth TEXT NOT NULL ) INHERITS( a.context );
    CREATE TABLE table2(
          id INTEGER NOT NULL
        , smth TEXT NOT NULL
        , table1_id INTEGER NOT NULL
        , CONSTRAINT fk_table2_table1_id FOREIGN KEY( table1_id ) REFERENCES table1(id) DEFERRABLE
    ) INHERITS( a.context );

    PERFORM hive.context_next_block( 'context' );

    INSERT INTO table1( id, smth ) VALUES( 123, 'blabla1' );
    INSERT INTO table2( id, smth, table1_id ) VALUES( 223, 'blabla2', 123 );
    -- cleans up shadow tables
    TRUNCATE hafd.shadow_public_table1;
    TRUNCATE hafd.shadow_public_table2;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_detach( 'context' );
    PERFORM hive.context_attach( 'context', 1 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT * FROM hafd.contexts hc JOIN hafd.contexts_attachment hca ON hca.context_id = hc.id WHERE hc.name = 'context' AND hca.is_attached = TRUE ), 'Context is not marked as attached';
END
$BODY$
;





