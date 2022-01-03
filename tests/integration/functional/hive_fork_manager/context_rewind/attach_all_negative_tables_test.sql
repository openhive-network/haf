DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'context2' );
    PERFORM hive.context_create( 'context_attached' );
    PERFORM hive.context_next_block( 'context2' ); -- 0
    PERFORM hive.context_next_block( 'context2' ); -- 1
    PERFORM hive.context_next_block( 'context2' ); -- 2
    PERFORM hive.context_detach( 'context2' );
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
BEGIN
    BEGIN
        -- no such context
        PERFORM hive.context_attach( 'context', 100 );
        ASSERT FALSE, "Did not catch expected exception for unexisted context";
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        -- block already processed
        PERFORM hive.context_attach( 'context2', 1 );
        ASSERT FALSE, "Did not catch expected exception when block num is to small";
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        -- atach already attached context
        PERFORM hive.context_attach( 'context_attached', 100 );
        ASSERT FALSE, "Did not catch expected exception when context was already attached";
    EXCEPTION WHEN OTHERS THEN
    END;
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
    -- nothing to do here
END
$BODY$
;




