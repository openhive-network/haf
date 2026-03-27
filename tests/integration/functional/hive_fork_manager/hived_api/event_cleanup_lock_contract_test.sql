-- Test: squash_and_get_state must hold ROW SHARE lock on contexts_attachment
--
-- This verifies the lock contract that prevents the FK violation crash when
-- pruned HAF runs an application concurrently with end_massive_sync.
-- Regression test for the race condition introduced by 3242af8a3.
--
-- Strategy: call squash_and_get_state inside a function, then immediately
-- check pg_locks within the same transaction to confirm a RowShareLock
-- is held on hafd.contexts_attachment.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Create blocks (matching schema used by other hived_api tests)
    INSERT INTO hafd.blocks
    VALUES
       ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1);

    -- Simulate massive sync events (as hived would produce during REINDEX)
    PERFORM hive.end_massive_sync(1);
    PERFORM hive.end_massive_sync(2);
    PERFORM hive.end_massive_sync(3);

    -- Create an application context
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name => 'context', _schema => 'a' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __has_lock BOOLEAN;
BEGIN
    -- Call squash_and_get_state — this should acquire ROW SHARE lock
    -- on hafd.contexts_attachment within this transaction.
    PERFORM hive.squash_and_get_state( ARRAY['context'] );

    -- Immediately check that the lock is held (same transaction).
    -- pg_locks shows all locks held by the current backend.
    SELECT EXISTS (
        SELECT 1
        FROM pg_locks l
        JOIN pg_class c ON c.oid = l.relation
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'hafd'
          AND c.relname = 'contexts_attachment'
          AND l.mode = 'RowShareLock'
          AND l.pid = pg_backend_pid()
    ) INTO __has_lock;

    ASSERT __has_lock,
        'squash_and_get_state must hold RowShareLock on hafd.contexts_attachment '
        'to prevent concurrent event deletion by end_massive_sync. '
        'Without this lock, pruned HAF crashes with FK violation '
        'when application squash functions race with event cleanup.';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Lock contract verified in the 'when' phase (must be checked in same transaction).
    -- Reaching here means squash_and_get_state correctly acquires RowShareLock.
    NULL;
END;
$BODY$
;
