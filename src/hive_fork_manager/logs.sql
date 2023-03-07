CREATE OR REPLACE FUNCTION hive.update_log_properties(lvl int)
    RETURNS void
    LANGUAGE 'plpgsql'

AS $BODY$
begin
update hive.log_properties set lvl = $1;
end;
$BODY$;

--DEBUG LOGS

CREATE OR REPLACE FUNCTION hive.dlog(context_name text, msg text)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
begin
    if (select lvl from hive.log_properties) >= 100 then
    RAISE DEBUG 'level="DEBUG" context="%" haflog=%', context_name, msg;
    end if;
end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.dlog(context_name text, msg1 text, arg1 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin
if (select lvl from hive.log_properties) >= 100 then
Select format(msg1, arg1) into msg;
RAISE DEBUG 'level="DEBUG" context="%" haflog=%', context_name, msg;
end if;

end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.dlog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin
if (select lvl from hive.log_properties) >= 100 then
Select format(msg1, arg1, arg2) into msg;
RAISE DEBUG 'level="DEBUG" context="%" haflog=%', context_name, msg;
end if;

end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.dlog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement, arg3 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin
if (select lvl from hive.log_properties) >= 100 then
Select format(msg1, arg1, arg2, arg3) into msg;
RAISE DEBUG 'level="DEBUG" context="%" haflog=%', context_name, msg;
end if;

end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.dlog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin

if (select lvl from hive.log_properties) >= 100 then
Select format(msg1, arg1, arg2, arg3, arg4) into msg;
RAISE DEBUG 'level="DEBUG" context="%" haflog=%', context_name, msg;
end if;

end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.dlog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin

if (select lvl from hive.log_properties) >= 100 then
Select format(msg1, arg1, arg2, arg3, arg4, arg5) into msg;
RAISE DEBUG 'level="DEBUG" context="%" haflog=%', context_name, msg;
end if;
end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.dlog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement, arg6 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin

if (select lvl from hive.log_properties) >= 100 then
Select format(msg1, arg1, arg2, arg3, arg4, arg5, arg6) into msg;
RAISE DEBUG 'level="DEBUG" context="%" haflog=%', context_name, msg;
end if;
end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.dlog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement, arg6 anyelement, arg7 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin

if (select lvl from hive.log_properties) >= 100 then
Select format(msg1, arg1, arg2, arg3, arg4, arg5, arg6, arg7) into msg;
RAISE DEBUG 'level="DEBUG" context="%" haflog=%', context_name, msg;
end if;
end;
$BODY$;

--ERROR LOGS

CREATE OR REPLACE FUNCTION hive.elog(context_name text, msg text)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
begin
if (select lvl from hive.log_properties) >= 40 then
RAISE EXCEPTION 'level="ERROR" context="%" haflog=''%''', context_name, msg;
end if;

end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.elog(context_name text, msg1 text, arg1 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin
if (select lvl from hive.log_properties) >= 40 then
Select format(msg1, arg1) into msg;
RAISE EXCEPTION 'level="ERROR" context="%" haflog=''%''', context_name, msg;
end if;

end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.elog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin
if (select lvl from hive.log_properties) >= 40 then
Select format(msg1, arg1, arg2) into msg;
RAISE EXCEPTION 'level="ERROR" context="%" haflog=''%''', context_name, msg;
end if;

end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.elog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement, arg3 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin
if (select lvl from hive.log_properties) >= 40 then
Select format(msg1, arg1, arg2, arg3) into msg;
RAISE EXCEPTION 'level="ERROR" context="%" haflog=''%''', context_name, msg;
end if;

end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.elog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin

if (select lvl from hive.log_properties) >= 40 then
Select format(msg1, arg1, arg2, arg3, arg4) into msg;
RAISE EXCEPTION 'level="ERROR" context="%" haflog=''%''', context_name, msg;
end if;

end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.elog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin

if (select lvl from hive.log_properties) >= 40 then
Select format(msg1, arg1, arg2, arg3, arg4, arg5) into msg;
RAISE EXCEPTION 'level="ERROR" context="%" haflog=''%''', context_name, msg;
end if;
end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.elog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement, arg6 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin

if (select lvl from hive.log_properties) >= 40 then
Select format(msg1, arg1, arg2, arg3, arg4, arg5, arg6) into msg;
RAISE EXCEPTION 'level="ERROR" context="%" haflog=''%''', context_name, msg;
end if;
end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.elog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement, arg6 anyelement, arg7 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin

if (select lvl from hive.log_properties) >= 40 then
Select format(msg1, arg1, arg2, arg3, arg4, arg5, arg6, arg7) into msg;
RAISE EXCEPTION 'level="ERROR" context="%" haflog=''%''', context_name, msg;
end if;
end;
$BODY$;


--INFO LOGS

CREATE OR REPLACE FUNCTION hive.ilog(context_name text, msg text)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$

begin
if (select lvl from hive.log_properties) >= 80 then
RAISE INFO 'level="INFO" context="%" haflog=''%''', context_name, msg;
end if;

end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.ilog(context_name text, msg1 text, arg1 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin
if (select lvl from hive.log_properties) >= 80 then
Select format(msg1, arg1) into msg;
RAISE INFO 'level="INFO" context="%" haflog=''%''', context_name, msg;
end if;

end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.ilog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin
if (select lvl from hive.log_properties) >= 80 then
Select format(msg1, arg1, arg2) into msg;
RAISE INFO 'level="INFO" context="%" haflog=''%''', context_name, msg;
end if;

end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.ilog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement, arg3 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin
if (select lvl from hive.log_properties) >= 80 then
Select format(msg1, arg1, arg2, arg3) into msg;
RAISE INFO 'level="INFO" context="%" haflog=''%''', context_name, msg;
end if;

end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.ilog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin

if (select lvl from hive.log_properties) >= 80 then
Select format(msg1, arg1, arg2, arg3, arg4) into msg;
RAISE INFO 'level="INFO" context="%" haflog=''%''', context_name, msg;
end if;

end;
$BODY$;


CREATE OR REPLACE FUNCTION hive.ilog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin

if (select lvl from hive.log_properties) >= 80 then
Select format(msg1, arg1, arg2, arg3, arg4, arg5) into msg;
RAISE INFO 'level="INFO" context="%" haflog=''%''', context_name, msg;
end if;
end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.ilog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement, arg6 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin

if (select lvl from hive.log_properties) >= 80 then
Select format(msg1, arg1, arg2, arg3, arg4, arg5, arg6) into msg;
RAISE INFO 'level="INFO" context="%" haflog=''%''', context_name, msg;
end if;
end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.ilog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement, arg6 anyelement, arg7 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin

if (select lvl from hive.log_properties) >= 80 then
Select format(msg1, arg1, arg2, arg3, arg4, arg5, arg6, arg7) into msg;
RAISE INFO 'level="INFO" context="%" haflog=''%''', context_name, msg;
end if;
end;
$BODY$;

--WARNING LOGS

CREATE OR REPLACE FUNCTION hive.wlog(context_name text, msg text)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
begin
if (select lvl from hive.log_properties) >= 60 then
RAISE WARNING 'level="WARNING" context="%" haflog=''%''', context_name, msg;
end if;

end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.wlog(context_name text, msg1 text, arg1 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin
if (select lvl from hive.log_properties) >= 60 then
Select format(msg1, arg1) into msg;
RAISE WARNING 'level="WARNING" context="%" haflog=''%''', context_name, msg;
end if;

end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.wlog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin
if (select lvl from hive.log_properties) >= 60 then
Select format(msg1, arg1, arg2) into msg;
RAISE WARNING 'level="WARNING" context="%" haflog=''%''', context_name, msg;
end if;

end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.wlog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement, arg3 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin
if (select lvl from hive.log_properties) >= 60 then
Select format(msg1, arg1, arg2, arg3) into msg;
RAISE WARNING 'level="WARNING" context="%" haflog=''%''', context_name, msg;
end if;

end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.wlog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin

if (select lvl from hive.log_properties) >= 60 then
Select format(msg1, arg1, arg2, arg3, arg4) into msg;
RAISE WARNING 'level="WARNING" context="%" haflog=''%''', context_name, msg;
end if;

end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.wlog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin

if (select lvl from hive.log_properties) >= 60 then
Select format(msg1, arg1, arg2, arg3, arg4, arg5) into msg;
RAISE WARNING 'level="WARNING" context="%" haflog=''%''', context_name, msg;
end if;
end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.wlog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement, arg6 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin

if (select lvl from hive.log_properties) >= 60 then
Select format(msg1, arg1, arg2, arg3, arg4, arg5, arg6) into msg;
RAISE WARNING 'level="WARNING" context="%" haflog=''%''', context_name, msg;
end if;
end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.wlog(context_name text, msg1 text, arg1 anyelement, arg2 anyelement, arg3 anyelement, arg4 anyelement, arg5 anyelement, arg6 anyelement, arg7 anyelement)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    msg text;
begin

if (select lvl from hive.log_properties) >= 60 then
Select format(msg1, arg1, arg2, arg3, arg4, arg5, arg6, arg7) into msg;
RAISE WARNING 'level="WARNING" context="%" haflog=''%''', context_name, msg;
end if;
end;
$BODY$;

