DROP FUNCTION IF EXISTS test_hived_test_given;
CREATE FUNCTION test_hived_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
    VALUES
       ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;
    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;
    PERFORM hive.end_massive_sync(5);
END;
$BODY$
;

DROP FUNCTION IF EXISTS alice_test_given;
CREATE FUNCTION alice_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'alice_context' );
    PERFORM hive.app_create_context( 'alice_context_detached' );
    PERFORM hive.app_context_detach( 'alice_context_detached' );
    CREATE TABLE alice_table( id INT ) INHERITS( hive.alice_context );
    PERFORM hive.app_next_block( 'alice_context' );
    PERFORM hive.app_next_block( ARRAY[ 'alice_context' ] );
    INSERT INTO alice_table VALUES( 10 );
END;
$BODY$
;


DROP FUNCTION IF EXISTS alice_test_then;
CREATE FUNCTION alice_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    BEGIN
        CREATE TABLE bob_in_bob_context(id INT ) INHERITS( hive.bob_context );
        ASSERT FALSE, 'Alice can create table in Bob''s context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_next_block( 'bob_context' );
        ASSERT FALSE, 'Alice can move forward Bob'' context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_next_block( ARRAY[ 'bob_context' ] );
        ASSERT FALSE, 'Alice can move forward Bob'' context as array';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_context_detach( 'bob_context' );
        ASSERT FALSE, 'Alice can detach Bob''s context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_context_detach( 'bob_context' );
        ASSERT FALSE, 'Alice can detach Bob''s context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_context_attach( 'bob_context_detached', 1 );
        ASSERT FALSE, 'Alice can attach Bob''s context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_context_attach( ARRAY[ 'bob_context_detached' ], 1 );
        ASSERT FALSE, 'Alice can attach Bob''s context array';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
            PERFORM hive.app_create_context( 'bob_context' );
            ASSERT FALSE, 'Alice can override Bob''s context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM * FROM alice_table;
    EXCEPTION WHEN OTHERS THEN
        ASSERT FALSE, 'Alice cannot read her own table';
    END;

    BEGIN
        PERFORM * FROM bob_table;
        ASSERT FALSE, 'Alice can read Bob''s tables';
        EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
            PERFORM * FROM hive.shadow_public_alice_table;
    EXCEPTION WHEN OTHERS THEN
            ASSERT FALSE, 'Alice cannot read her own shadow table';
    END;

    BEGIN
            PERFORM * FROM hive.shadow_public_bob_table;
            ASSERT FALSE, 'Alice can read Bobs''s shadow table';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        UPDATE hive.shadow_public_bob_table SET hive_rowid = 0;
        ASSERT FALSE, 'Alice can update Bob''s shadow table';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM hive.shadow_public_bob_table;
        ASSERT FALSE, 'Alice can delete from Bob''s shadow table';
        EXCEPTION WHEN OTHERS THEN
    END;

    ASSERT NOT EXISTS( SELECT * FROM hive.triggers WHERE trigger_name='hive_insert_trigger_public_bob_table' ), 'Alice can see Bobs''s trigers from hive.triggers';
    ASSERT NOT EXISTS( SELECT * FROM hive.registered_tables WHERE origin_table_name='bob_table' ), 'Alice can see Bobs''s tables from hive.registered_tables';

    BEGIN
        DROP VIEW IF EXISTS hive.bob_context_accounts_view;
        ASSERT FALSE, 'Alice can drop Bob''s accounts views';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DROP VIEW IF EXISTS hive.bob_context_account_operations_view;
        ASSERT FALSE, 'Alice can drop Bob''s account_operations views';
    EXCEPTION WHEN OTHERS THEN
    END;

    ASSERT NOT EXISTS( SELECT * FROM hive.state_providers_registered ), 'Alice sees Bobs registered state provider';

    BEGIN
        PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'bob_context' );
        ASSERT FALSE, 'Alice can import state providers to Bob context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_state_providers_update( 0, 100, 'bob_context' );
        ASSERT FALSE, 'Alice can update Bobs state providers';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_state_providers_update( 0, 100, 'bob_context' );
        ASSERT FALSE, 'Alice can update Bobs state providers';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_state_provider_drop( 'ACCOUNTS', 'bob_context' );
        ASSERT FALSE, 'Alice can drop Bobs state providers';
    EXCEPTION WHEN OTHERS THEN
    END;

END;
$BODY$
;

DROP FUNCTION IF EXISTS bob_test_given;
CREATE FUNCTION bob_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'bob_context' );
    PERFORM hive.app_create_context( 'bob_context_detached' );
    PERFORM hive.app_context_detach( 'bob_context_detached' );
    CREATE TABLE bob_table( id INT ) INHERITS( hive.bob_context );
    PERFORM hive.app_next_block( 'bob_context' );
    PERFORM hive.app_next_block( ARRAY[ 'bob_context' ] );
    INSERT INTO bob_table VALUES( 100 );
    PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'bob_context' );
END;
$BODY$
;

DROP FUNCTION IF EXISTS bob_test_then;
CREATE FUNCTION bob_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    BEGIN
        CREATE TABLE bob_in_alice_context(id INT ) INHERITS( hive.alice_context );
        ASSERT FALSE, 'Bob can create table in Alice''s context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_next_block( 'alice_context' );
        ASSERT FALSE, 'Bob can move forward Alice'' context';
        EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_next_block( ARRAY[ 'alice_context' ] );
        ASSERT FALSE, 'Bob can move forward Alice'' context as array';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_context_detach( 'alice_context' );
        ASSERT FALSE, 'Bob can detach Alice''s context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_context_attach( 'alice_context_detached', 1 );
        ASSERT FALSE, 'Bob can attach Alice''s context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_context_attach( ARRAY[ 'alice_context_detached' ], 1 );
        ASSERT FALSE, 'Bob can attach Alice''s context array';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_create_context( 'alice_context' );
        ASSERT FALSE, 'Bob can override Alice''s context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM * FROM alice_table;
        ASSERT FALSE, 'Bob can read Alice''s tables';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM * FROM bob_table;
    EXCEPTION WHEN OTHERS THEN
        ASSERT FALSE, 'Bob cannot read his own table';
    END;

    BEGIN
        PERFORM * FROM hive.shadow_public_bob_table;
    EXCEPTION WHEN OTHERS THEN
        ASSERT FALSE, 'Bob cannot read his own shadow table';
    END;

    BEGIN
        PERFORM * FROM hive.shadow_public_alice_table;
        ASSERT FALSE, 'Bob can read Alice''s shadow table';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        UPDATE hive.shadow_public_alice_table SET hive_rowid = 0;
        ASSERT FALSE, 'Bob can update Alice''s shadow table';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM hive.shadow_public_alice_table;
        ASSERT FALSE, 'Bob can delete from Alice''s shadow table';
        EXCEPTION WHEN OTHERS THEN
    END;

    ASSERT NOT EXISTS( SELECT * FROM hive.triggers WHERE trigger_name='hive_insert_trigger_public_alice_table' ), 'Bob can see Alice''s trigers from hive.triggers';
    ASSERT NOT EXISTS( SELECT * FROM hive.registered_tables WHERE origin_table_name='alice_table' ), 'Bob can see Alice''s tables from hive.registered_tables';

    BEGIN
        DROP VIEW IF EXISTS hive.alice_context_blocks_view;
        ASSERT FALSE, 'Bob can drop Alice''s blocks views';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DROP VIEW IF EXISTS hive.alice_context_accounts_view;
        ASSERT FALSE, 'Bob can drop Alice''s accounts views';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DROP VIEW IF EXISTS hive.alice_context_account_operations_view;
        ASSERT FALSE, 'Bob can drop Alice''s account_operations views';
    EXCEPTION WHEN OTHERS THEN
    END;

    ASSERT ( SELECT COUNT(*) FROM hive.state_providers_registered ) = 1, 'Bob lost his state providers';
END;
$BODY$
;
