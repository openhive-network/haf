SET ROLE test_app_owner;

CREATE OR REPLACE PROCEDURE test.scenario1_prepare(IN _time_shift INTERVAL = '3 hrs'::interval)
LANGUAGE 'plpgsql'
AS
$$
BEGIN
  --- Verify that only context of dead application will be detached.
  IF hive.app_context_exists('active_app') THEN
    PERFORM hive.app_remove_context('active_app');
  END IF;

  PERFORM hive.app_create_context('active_app');
  PERFORM test.validate_activity_time('active_app'); -- last activity time should be updated

  IF hive.app_context_exists('dead_app1') THEN
    PERFORM hive.app_remove_context('dead_app1');
  END IF;

  PERFORM hive.app_create_context('dead_app1');
  PERFORM test.validate_activity_time('dead_app1'); -- last activity time should be updated

  CALL test_app.main('active_app', 100);
  CALL test_app.main('dead_app1', 100);

  -- just to "shift" in time
  UPDATE hive.contexts
    SET last_active_at = last_active_at - _time_shift
    WHERE name = 'dead_app1';

  COMMIT;
END
$$
;

CREATE OR REPLACE PROCEDURE test.scenario1_verify(IN _time_shift INTERVAL = '3 hrs'::interval)
LANGUAGE 'plpgsql'
AS
$$
BEGIN
   SET ROLE test_app_owner;

   PERFORM test.verify_is_attached_context('active_app', TRUE);
   PERFORM test.verify_is_attached_context('dead_app1', FALSE);
END
$$

RESET ROLE;
