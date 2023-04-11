DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'context' );
    CREATE TABLE table1( id INTEGER PRIMARY KEY, smth TEXT NOT NULL ) INHERITS( hive.context );
    CREATE TABLE table2(
          id INTEGER NOT NULL
        , smth TEXT NOT NULL
        , table1_id INTEGER NOT NULL
        , CONSTRAINT fk_table2_table1_id FOREIGN KEY( table1_id ) REFERENCES table1(id) DEFERRABLE
    ) INHERITS( hive.context );

    PERFORM hive.context_next_block( 'context' );

    INSERT INTO table1( id, smth ) VALUES( 123, 'blabla1' );
    INSERT INTO table2( id, smth, table1_id ) VALUES( 223, 'blabla2', 123 );
    -- cleans up shadow tables
    TRUNCATE hive.shadow_public_table1;
    TRUNCATE hive.shadow_public_table2;
END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.context_detach( 'context' );
    PERFORM hive.context_attach( 'context', 1 );
END
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT * FROM hive.contexts WHERE name = 'context' AND is_attached = TRUE ), 'Context is not marked as attached';
END
$BODY$
;





