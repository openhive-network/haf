﻿
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context', 'a' );
    CREATE TABLE table1( id INTEGER NOT NULL ) INHERITS( a.context );
    PERFORM hive.context_next_block( 'context' ); -- 1
    INSERT INTO table1( id ) VALUES( 0 );
    PERFORM hive.context_next_block( 'context' ); -- 2
    INSERT INTO table1( id ) VALUES( 1 );
    PERFORM hive.context_next_block( 'context' ); -- 3
    INSERT INTO table1( id ) VALUES( 2 );
    PERFORM hive.context_next_block( 'context' ); -- 4
    INSERT INTO table1( id ) VALUES( 3 );

    PERFORM hive.context_create( 'context2', 'a' );
    CREATE TABLE table2( id INTEGER NOT NULL ) INHERITS( a.context2 );
    PERFORM hive.context_next_block( 'context2' ); -- 1
    INSERT INTO table2( id ) VALUES( 0 );
    PERFORM hive.context_next_block( 'context2' ); -- 2
    INSERT INTO table2( id ) VALUES( 1 );
    PERFORM hive.context_next_block( 'context2' ); -- 3
    INSERT INTO table2( id ) VALUES( 2 );
    PERFORM hive.context_next_block( 'context2' ); -- 4
    INSERT INTO table2( id ) VALUES( 3 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_set_irreversible_block( 'context', 3 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_public_table1 ) = 1, 'Wrong number of rows in the shadow table1';
    ASSERT EXISTS ( SELECT FROM hafd.shadow_public_table1 hs WHERE hs.id = 3 AND hive_block_num = 4 ), 'No expected row';
    ASSERT EXISTS ( SELECT FROM hafd.contexts hc WHERE hc.name = 'context' AND hc.irreversible_block = 3 ), 'Wrong irreversible block';

    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_public_table2 ) = 4, 'Wrong number of rows in the shadow table2';
END
$BODY$
;




