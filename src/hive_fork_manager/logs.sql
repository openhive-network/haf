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
    RAISE DEBUG 'context="%" haflog="%"', context_name, msg;
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
RAISE DEBUG 'context="%" haflog="%"', context_name, msg;
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
RAISE DEBUG 'context="%" haflog="%"', context_name, msg;
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
RAISE DEBUG 'context="%" haflog="%"', context_name, msg;
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
RAISE DEBUG 'context="%" haflog="%"', context_name, msg;
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
RAISE EXCEPTION 'context="%" haflog="%"', context_name, msg;
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
RAISE EXCEPTION 'context="%" haflog="%"', context_name, msg;
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
RAISE EXCEPTION 'context="%" haflog="%"', context_name, msg;
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
RAISE EXCEPTION 'context="%" haflog="%"', context_name, msg;
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
RAISE EXCEPTION 'context="%" haflog="%"', context_name, msg;
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
RAISE INFO 'context="%" haflog="%"', context_name, msg;
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
RAISE INFO 'context="%" haflog="%"', context_name, msg;
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
RAISE INFO 'context="%" haflog="%"', context_name, msg;
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
RAISE INFO 'context="%" haflog="%"', context_name, msg;
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
RAISE INFO 'context="%" haflog="%"', context_name, msg;
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
RAISE WARNING 'context="%" haflog="%"', context_name, msg;
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
RAISE WARNING 'context="%" haflog="%"', context_name, msg;
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
RAISE WARNING 'context="%" haflog="%"', context_name, msg;
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
RAISE WARNING 'context="%" haflog="%"', context_name, msg;
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
RAISE WARNING 'context="%" haflog="%"', context_name, msg;
end if;

end;
$BODY$;

CREATE OR REPLACE FUNCTION hive.test_logs1(
	context_name text)
    RETURNS void
    LANGUAGE 'plpgsql'
AS 
$BODY$
DECLARE
    _res int :=0;
begin
    while _res < 10000 loop
	
    PERFORM hive.dlog(context_name, _res :: text);
	raise notice 'Counter %', _res;
	_res := _res +1;
	
    end loop;
end;
$BODY$;
