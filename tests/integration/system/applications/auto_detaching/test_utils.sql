SET ROLE haf_admin; 

DO
$$
BEGIN
  CREATE ROLE test_owner WITH LOGIN INHERIT IN ROLE haf_admin;

EXCEPTION WHEN duplicate_object THEN
  DROP OWNED BY test_owner  CASCADE;
  DROP ROLE test_owner;

  CREATE ROLE test_owner WITH LOGIN INHERIT IN ROLE haf_admin;
END
$$;

SET ROLE test_owner;

CREATE SCHEMA test AUTHORIZATION test_owner;

CREATE OR REPLACE FUNCTION test.validate_activity_time(IN _contextName hive.context_name, IN _accepted_margin INTERVAL = '1 min'::INTERVAL)
  RETURNS void
  LANGUAGE plpgsql
  STABLE
AS
$BODY$
DECLARE
  __last_activity TIMESTAMP WITHOUT TIME ZONE;
  __now TIMESTAMP WITHOUT TIME ZONE := NOW();
  __time_shift INTERVAL;
BEGIN
  SELECT c.last_active_at INTO __last_activity
         FROM hive.contexts c
         WHERE c.name = _contextName;
  
   IF __last_activity  IS NULL OR NOT __last_activity BETWEEN __now - _accepted_margin AND __now + _accepted_margin THEN
     RAISE 'Context: % activity time: % is out of expected range: [%,%]', _contextName,
       __last_activity, __now - _accepted_margin, __now + _accepted_margin
       USING ERRCODE = 'assert_failure';
   END IF;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION test.verify_is_attached_context(IN _contextName hive.context_name, IN _expected BOOLEAN)
  RETURNS void
  LANGUAGE plpgsql
  STABLE
AS
$BODY$
DECLARE
  __is_attached BOOLEAN;
BEGIN
  __is_attached := hive.app_context_is_attached(_contextName);
   IF __is_attached != _expected THEN
     RAISE EXCEPTION 'Context: % attach status: % does not match expected value: %', _contextName,
       __is_attached, _expected 
        USING ERRCODE = 'assert_failure';
   END IF;
END;
$BODY$
;

RESET ROLE;

SET ROLE haf_admin; 

GRANT test_app_owner to test_owner;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA test TO test_app_owner;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA test TO test_app_owner;
GRANT all ON SCHEMA test TO test_app_owner;
GRANT USAGE ON SCHEMA test TO test_app_owner;
