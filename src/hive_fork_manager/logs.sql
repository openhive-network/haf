CREATE OR REPLACE FUNCTION hive.update_log_properties(lvl INT)
    RETURNS void
    LANGUAGE 'plpgsql'

AS $BODY$
BEGIN
update hive.log_properties set lvl = $1;
END;
$BODY$;

--DEBUG LOGS

CREATE OR REPLACE FUNCTION hive.dlog(context_name TEXT, msg TEXT)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    IF (SELECT lvl FROM hive.log_properties) >= 100 THEN
    RAISE DEBUG 'level="DEBUG" context="%" haflog=%', context_name, msg;
    END IF;
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.dlog(context_name TEXT, msg1 TEXT, arg1 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN
IF (SELECT lvl FROM hive.log_properties) >= 100 THEN
SELECT format(msg1, arg1) INTO msg;
RAISE DEBUG 'level="DEBUG" context="%" haflog=%', context_name, msg;
END IF;

END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.dlog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN
IF (SELECT lvl FROM hive.log_properties) >= 100 THEN
SELECT format(msg1, arg1, arg2) INTO msg;
RAISE DEBUG 'level="DEBUG" context="%" haflog=%', context_name, msg;
END IF;

END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.dlog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement, arg3 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN
IF (SELECT lvl FROM hive.log_properties) >= 100 THEN
SELECT format(msg1, arg1, arg2, arg3) INTO msg;
RAISE DEBUG 'level="DEBUG" context="%" haflog=%', context_name, msg;
END IF;

END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.dlog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN

IF (SELECT lvl FROM hive.log_properties) >= 100 THEN
SELECT format(msg1, arg1, arg2, arg3, arg4) INTO msg;
RAISE DEBUG 'level="DEBUG" context="%" haflog=%', context_name, msg;
END IF;

END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.dlog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN

IF (SELECT lvl FROM hive.log_properties) >= 100 THEN
SELECT format(msg1, arg1, arg2, arg3, arg4, arg5) INTO msg;
RAISE DEBUG 'level="DEBUG" context="%" haflog=%', context_name, msg;
END IF;
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.dlog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement, arg6 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN

IF (SELECT lvl FROM hive.log_properties) >= 100 THEN
SELECT format(msg1, arg1, arg2, arg3, arg4, arg5, arg6) INTO msg;
RAISE DEBUG 'level="DEBUG" context="%" haflog=%', context_name, msg;
END IF;
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.dlog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement, arg6 anyelement, arg7 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN

IF (SELECT lvl FROM hive.log_properties) >= 100 THEN
SELECT format(msg1, arg1, arg2, arg3, arg4, arg5, arg6, arg7) INTO msg;
RAISE DEBUG 'level="DEBUG" context="%" haflog=%', context_name, msg;
END IF;
END;
$BODY$;

--ERROR LOGS

CREATE OR REPLACE FUNCTION hive.elog(context_name TEXT, msg TEXT)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
IF (SELECT lvl FROM hive.log_properties) >= 40 THEN
RAISE EXCEPTION 'level="ERROR" context="%" haflog=''%''', context_name, msg;
END IF;

END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.elog(context_name TEXT, msg1 TEXT, arg1 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN
IF (SELECT lvl FROM hive.log_properties) >= 40 THEN
SELECT format(msg1, arg1) INTO msg;
RAISE EXCEPTION 'level="ERROR" context="%" haflog=''%''', context_name, msg;
END IF;

END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.elog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN
IF (SELECT lvl FROM hive.log_properties) >= 40 THEN
SELECT format(msg1, arg1, arg2) INTO msg;
RAISE EXCEPTION 'level="ERROR" context="%" haflog=''%''', context_name, msg;
END IF;

END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.elog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement, arg3 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN
IF (SELECT lvl FROM hive.log_properties) >= 40 THEN
SELECT format(msg1, arg1, arg2, arg3) INTO msg;
RAISE EXCEPTION 'level="ERROR" context="%" haflog=''%''', context_name, msg;
END IF;

END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.elog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN

IF (SELECT lvl FROM hive.log_properties) >= 40 THEN
SELECT format(msg1, arg1, arg2, arg3, arg4) INTO msg;
RAISE EXCEPTION 'level="ERROR" context="%" haflog=''%''', context_name, msg;
END IF;

END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.elog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN

IF (SELECT lvl FROM hive.log_properties) >= 40 THEN
SELECT format(msg1, arg1, arg2, arg3, arg4, arg5) INTO msg;
RAISE EXCEPTION 'level="ERROR" context="%" haflog=''%''', context_name, msg;
END IF;
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.elog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement, arg6 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN

IF (SELECT lvl FROM hive.log_properties) >= 40 THEN
SELECT format(msg1, arg1, arg2, arg3, arg4, arg5, arg6) INTO msg;
RAISE EXCEPTION 'level="ERROR" context="%" haflog=''%''', context_name, msg;
END IF;
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.elog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement, arg6 anyelement, arg7 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN

IF (SELECT lvl FROM hive.log_properties) >= 40 THEN
SELECT format(msg1, arg1, arg2, arg3, arg4, arg5, arg6, arg7) INTO msg;
RAISE EXCEPTION 'level="ERROR" context="%" haflog=''%''', context_name, msg;
END IF;
END;
$BODY$;


--INFO LOGS

CREATE OR REPLACE FUNCTION hive.ilog(context_name TEXT, msg TEXT)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$

BEGIN
IF (SELECT lvl FROM hive.log_properties) >= 80 THEN
RAISE INFO 'level="INFO" context="%" haflog=''%''', context_name, msg;
END IF;

END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.ilog(context_name TEXT, msg1 TEXT, arg1 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN
IF (SELECT lvl FROM hive.log_properties) >= 80 THEN
SELECT format(msg1, arg1) INTO msg;
RAISE INFO 'level="INFO" context="%" haflog=''%''', context_name, msg;
END IF;

END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.ilog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN
IF (SELECT lvl FROM hive.log_properties) >= 80 THEN
SELECT format(msg1, arg1, arg2) INTO msg;
RAISE INFO 'level="INFO" context="%" haflog=''%''', context_name, msg;
END IF;

END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.ilog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement, arg3 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN
IF (SELECT lvl FROM hive.log_properties) >= 80 THEN
SELECT format(msg1, arg1, arg2, arg3) INTO msg;
RAISE INFO 'level="INFO" context="%" haflog=''%''', context_name, msg;
END IF;

END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.ilog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN

IF (SELECT lvl FROM hive.log_properties) >= 80 THEN
SELECT format(msg1, arg1, arg2, arg3, arg4) INTO msg;
RAISE INFO 'level="INFO" context="%" haflog=''%''', context_name, msg;
END IF;

END;
$BODY$;


CREATE OR REPLACE FUNCTION hive.ilog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN

IF (SELECT lvl FROM hive.log_properties) >= 80 THEN
SELECT format(msg1, arg1, arg2, arg3, arg4, arg5) INTO msg;
RAISE INFO 'level="INFO" context="%" haflog=''%''', context_name, msg;
END IF;
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.ilog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement, arg6 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN

IF (SELECT lvl FROM hive.log_properties) >= 80 THEN
SELECT format(msg1, arg1, arg2, arg3, arg4, arg5, arg6) INTO msg;
RAISE INFO 'level="INFO" context="%" haflog=''%''', context_name, msg;
END IF;
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.ilog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement, arg6 anyelement, arg7 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN

IF (SELECT lvl FROM hive.log_properties) >= 80 THEN
SELECT format(msg1, arg1, arg2, arg3, arg4, arg5, arg6, arg7) INTO msg;
RAISE INFO 'level="INFO" context="%" haflog=''%''', context_name, msg;
END IF;
END;
$BODY$;

--WARNING LOGS

CREATE OR REPLACE FUNCTION hive.wlog(context_name TEXT, msg TEXT)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
IF (SELECT lvl FROM hive.log_properties) >= 60 THEN
RAISE WARNING 'level="WARNING" context="%" haflog=''%''', context_name, msg;
END IF;

END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.wlog(context_name TEXT, msg1 TEXT, arg1 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN
IF (SELECT lvl FROM hive.log_properties) >= 60 THEN
SELECT format(msg1, arg1) INTO msg;
RAISE WARNING 'level="WARNING" context="%" haflog=''%''', context_name, msg;
END IF;

END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.wlog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN
IF (SELECT lvl FROM hive.log_properties) >= 60 THEN
SELECT format(msg1, arg1, arg2) INTO msg;
RAISE WARNING 'level="WARNING" context="%" haflog=''%''', context_name, msg;
END IF;

END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.wlog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement, arg3 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN
IF (SELECT lvl FROM hive.log_properties) >= 60 THEN
SELECT format(msg1, arg1, arg2, arg3) INTO msg;
RAISE WARNING 'level="WARNING" context="%" haflog=''%''', context_name, msg;
END IF;

END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.wlog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN

IF (SELECT lvl FROM hive.log_properties) >= 60 THEN
SELECT format(msg1, arg1, arg2, arg3, arg4) INTO msg;
RAISE WARNING 'level="WARNING" context="%" haflog=''%''', context_name, msg;
END IF;

END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.wlog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN

IF (SELECT lvl FROM hive.log_properties) >= 60 THEN
SELECT format(msg1, arg1, arg2, arg3, arg4, arg5) INTO msg;
RAISE WARNING 'level="WARNING" context="%" haflog=''%''', context_name, msg;
END IF;
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.wlog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement, arg6 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN

IF (SELECT lvl FROM hive.log_properties) >= 60 THEN
SELECT format(msg1, arg1, arg2, arg3, arg4, arg5, arg6) INTO msg;
RAISE WARNING 'level="WARNING" context="%" haflog=''%''', context_name, msg;
END IF;
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.wlog(context_name TEXT, msg1 TEXT, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement, arg6 anyelement, arg7 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg TEXT;
BEGIN

IF (SELECT lvl FROM hive.log_properties) >= 60 THEN
SELECT format(msg1, arg1, arg2, arg3, arg4, arg5, arg6, arg7) INTO msg;
RAISE WARNING 'level="WARNING" context="%" haflog=''%''', context_name, msg;
END IF;
END;
$BODY$;

