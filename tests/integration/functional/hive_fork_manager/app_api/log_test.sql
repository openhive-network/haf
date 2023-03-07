DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN

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
DECLARE
  arg1 TEXT := 'test1';
  arg2 TEXT := 'test2';
  arg3 TEXT := 'test3';
  arg4 TEXT := 'test4';
  arg5 TEXT := 'test5';
  arg6 TEXT := 'test6';
  arg7 TEXT := 'test7';
  is_exception_happened BOOL := FALSE;
  is_exception_happened1 BOOL := FALSE;
  is_exception_happened2 BOOL := FALSE;
  is_exception_happened3 BOOL := FALSE;
  is_exception_happened4 BOOL := FALSE;
  is_exception_happened5 BOOL := FALSE;
  is_exception_happened6 BOOL := FALSE;
  is_exception_happened7 BOOL := FALSE;
BEGIN

PERFORM hive.dlog('no-arguments', 'test');
PERFORM hive.dlog('one-arguments', 'test %s', arg1);
PERFORM hive.dlog('two-arguments', 'test %s, %s', arg1, arg2);
PERFORM hive.dlog('three-arguments', 'test %s, %s, %s', arg1, arg2, arg3);
PERFORM hive.dlog('four-arguments', 'test %s, %s, %s, %s', arg1, arg2, arg3, arg4);
PERFORM hive.dlog('five-arguments', 'test %s, %s, %s, %s, %s', arg1, arg2, arg3, arg4, arg5);
PERFORM hive.dlog('six-arguments', 'test %s, %s, %s, %s, %s, %s', arg1, arg2, arg3, arg4, arg5, arg6);
PERFORM hive.dlog('seven-arguments', 'test %s, %s, %s, %s, %s, %s, %s', arg1, arg2, arg3, arg4, arg5, arg6, arg7);

PERFORM hive.ilog('no-arguments', 'test');
PERFORM hive.ilog('one-arguments', 'test %s', arg1);
PERFORM hive.ilog('two-arguments', 'test %s, %s', arg1, arg2);
PERFORM hive.ilog('three-arguments', 'test %s, %s, %s', arg1, arg2, arg3);
PERFORM hive.ilog('four-arguments', 'test %s, %s, %s, %s', arg1, arg2, arg3, arg4);
PERFORM hive.ilog('five-arguments', 'test %s, %s, %s, %s, %s', arg1, arg2, arg3, arg4, arg5);
PERFORM hive.ilog('six-arguments', 'test %s, %s, %s, %s, %s, %s', arg1, arg2, arg3, arg4, arg5, arg6);
PERFORM hive.ilog('seven-arguments', 'test %s, %s, %s, %s, %s, %s, %s', arg1, arg2, arg3, arg4, arg5, arg6, arg7);

PERFORM hive.wlog('no-arguments', 'test');
PERFORM hive.wlog('one-arguments', 'test %s', arg1);
PERFORM hive.wlog('two-arguments', 'test %s, %s', arg1, arg2);
PERFORM hive.wlog('three-arguments', 'test %s, %s, %s', arg1, arg2, arg3);
PERFORM hive.wlog('four-arguments', 'test %s, %s, %s, %s', arg1, arg2, arg3, arg4);
PERFORM hive.wlog('five-arguments', 'test %s, %s, %s, %s, %s', arg1, arg2, arg3, arg4, arg5);
PERFORM hive.wlog('six-arguments', 'test %s, %s, %s, %s, %s, %s', arg1, arg2, arg3, arg4, arg5, arg6);
PERFORM hive.wlog('seven-arguments', 'test %s, %s, %s, %s, %s, %s, %s', arg1, arg2, arg3, arg4, arg5, arg6, arg7);

    BEGIN
        PERFORM hive.elog('no-arguments', 'test');
        EXCEPTION WHEN OTHERS THEN
            SELECT TRUE INTO is_exception_happened;
    END;
    ASSERT is_exception_happened;
    BEGIN
        PERFORM hive.elog('one-arguments', 'test %s', arg1);
        EXCEPTION WHEN OTHERS THEN
            SELECT TRUE INTO is_exception_happened1;
    END;
    ASSERT is_exception_happened1;
    BEGIN
        PERFORM hive.elog('two-arguments', 'test %s, %s', arg1, arg2);
        EXCEPTION WHEN OTHERS THEN
            SELECT TRUE INTO is_exception_happened2;
    END;
    ASSERT is_exception_happened2;
    BEGIN
        PERFORM hive.elog('three-arguments', 'test %s, %s, %s', arg1, arg2, arg3);
        EXCEPTION WHEN OTHERS THEN
            SELECT TRUE INTO is_exception_happened3;
    END;
    ASSERT is_exception_happened3;
    BEGIN
        PERFORM hive.elog('four-arguments', 'test %s, %s, %s, %s', arg1, arg2, arg3, arg4);
        EXCEPTION WHEN OTHERS THEN
            SELECT TRUE INTO is_exception_happened4;
    END;
    ASSERT is_exception_happened4;
    BEGIN
        PERFORM hive.elog('five-arguments', 'test %s, %s, %s, %s, %s', arg1, arg2, arg3, arg4, arg5);
        EXCEPTION WHEN OTHERS THEN
            SELECT TRUE INTO is_exception_happened5;
    END;
    ASSERT is_exception_happened5;
    BEGIN
        PERFORM hive.elog('six-arguments', 'test %s, %s, %s, %s, %s, %s', arg1, arg2, arg3, arg4, arg5, arg6);
        EXCEPTION WHEN OTHERS THEN
            SELECT TRUE INTO is_exception_happened6;
    END;
    ASSERT is_exception_happened6;
    BEGIN
        PERFORM hive.elog('seven-arguments', 'test %s, %s, %s, %s, %s, %s, %s', arg1, arg2, arg3, arg4, arg5, arg6, arg7);
        EXCEPTION WHEN OTHERS THEN
            SELECT TRUE INTO is_exception_happened7;
    END;
    ASSERT is_exception_happened7;

END
$BODY$
;




