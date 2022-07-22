CREATE TABLE IF NOT EXISTS hive.log_level(lvl int);

insert into log_level (lvl) values (100);



CREATE OR REPLACE PROCEDURE hive.update_log_level(int)
LANGUAGE 'plpgsql'

AS $BODY$
begin
update hive.log_level set lvl = $1;

end;
$BODY$;

CREATE OR REPLACE PROCEDURE hive.dlogs(context_name text, msg text)
LANGUAGE 'plpgsql'

AS $BODY$
begin
if (select lvl from hive.log_level) >= 100 then
call hive.logs(context_name, msg);
end if;

end;
$BODY$;

CREATE OR REPLACE PROCEDURE hive.elogs(context_name text, msg text, raise_except boolean)
LANGUAGE 'plpgsql'

AS $BODY$
begin
if (select lvl from hive.log_level) >= 40 then
call hive.logs(context_name, msg);
end if;

if raise_except then 
    RAISE EXCEPTION msg;
end if;

end;
$BODY$;

CREATE OR REPLACE PROCEDURE hive.ilogs(context_name text, msg text)
LANGUAGE 'plpgsql'
AS $BODY$
begin
if (select lvl from hive.log_level) >= 80 then
call hive.logs(context_name, msg);
end if;

end;
$BODY$;

CREATE OR REPLACE PROCEDURE hive.wlogs(context_name text, msg text)
LANGUAGE 'plpgsql'

AS $BODY$
begin
if (select lvl from hive.log_level) >= 60 then
call hive.logs(context_name, msg);
end if;

end;
$BODY$;

CREATE OR REPLACE PROCEDURE hive.logs(context_name text, msg text)
LANGUAGE 'plpgsql'

AS $BODY$
begin
perform http_post('http://localhost:3100/loki/api/v1/push', (
select
json_build_object(
    'streams', json_build_array(
    json_build_object(
        'stream',json_build_object(
            'hive', context_name),'values', json_build_array(json_build_array(
                ((extract(epoch from now()):: bigint)*1000000000) ::TEXT, msg))))))::text,
                        'application/json');
end;
$BODY$;