-- The shared HAF service's per-run clone API, installed by serve.sh into the
-- haf_shared database as postgres on every start (idempotent).
--
-- Each test run gets its own database, run_<id>, created from the frozen
-- haf_template with STRATEGY FILE_COPY: under file_copy_method = clone on ZFS
-- that clones the template's files instead of copying them. CREATE/DROP
-- DATABASE cannot run inside a function's transaction, so they go through a
-- dblink loopback connection as postgres. The run is registered (and
-- committed) before its database exists, so the reaper never mistakes a clone
-- in progress for an orphan.

create schema if not exists dblink;
revoke all on schema dblink from public;
create extension if not exists dblink with schema dblink;

create schema if not exists haf_shared;

-- The role consumers log in as, without a password (the compose file trusts
-- the fleet's LAN): it may create and drop run databases, and inside its own
-- clones it is a HAF application owner.
do $$
begin
    create role haf_shared_consumer login inherit in role hive_applications_owner_group;
exception when duplicate_object then
    null;
end
$$;

create table if not exists haf_shared.template (
    database_name text primary key,
    haf_commit text not null,
    head_block bigint not null,
    seeded_at timestamptz not null default now()
);

create table if not exists haf_shared.run_databases (
    run_id text primary key,
    database_name text not null unique,
    created_by name not null,
    created_at timestamptz not null default now()
);

create or replace function haf_shared._loopback(_database text, _sql text)
returns void
language plpgsql
set search_path = pg_catalog
as $$
begin
    perform dblink.dblink_exec(
        format('dbname=%s user=postgres port=%s', _database, current_setting('port')),
        _sql);
end
$$;

create or replace function haf_shared._run_database_name(_run_id text)
returns text
language plpgsql
immutable
as $$
begin
    if _run_id is null or _run_id !~ '^[a-z0-9][a-z0-9_-]{0,47}$' then
        raise exception 'run id must be 1-48 lowercase letters, digits, "_" or "-", starting with a letter or digit, got %', _run_id
            using errcode = 'invalid_parameter_value';
    end if;
    return 'run_' || _run_id;
end
$$;

-- Creates the run's database as a clone of the template, owned by the caller,
-- and returns its name. Raises unique_violation when the run already has one.
create or replace function haf_shared.clone_run_database(_run_id text)
returns text
language plpgsql
security definer
set search_path = pg_catalog, haf_shared
as $$
declare
    _name text := haf_shared._run_database_name(_run_id);
    _template text;
begin
    select database_name into strict _template from haf_shared.template;
    perform haf_shared._loopback(current_database(), format(
        'insert into haf_shared.run_databases (run_id, database_name, created_by) values (%L, %L, %L)',
        _run_id, _name, session_user));
    begin
        perform haf_shared._loopback('postgres', format(
            'create database %I owner %I template %I strategy file_copy',
            _name, session_user, _template));
    exception when others then
        perform haf_shared._loopback(current_database(), format(
            'delete from haf_shared.run_databases where run_id = %L', _run_id));
        raise;
    end;
    return _name;
end
$$;

-- Drops the run's database (closing its connections) and forgets the run.
-- A run without a database is not an error.
create or replace function haf_shared.drop_run_database(_run_id text)
returns void
language plpgsql
security definer
set search_path = pg_catalog, haf_shared
as $$
declare
    _name text := haf_shared._run_database_name(_run_id);
begin
    perform haf_shared._loopback('postgres', format('drop database if exists %I with (force)', _name));
    delete from haf_shared.run_databases where run_id = _run_id;
end
$$;

-- Drops every run database created more than _ttl ago, and every run_*
-- database no run is registered for (left by a failed clone or a lost
-- registry); forgets runs whose database is gone. Returns the dropped names.
create or replace function haf_shared.reap_run_databases(_ttl interval default interval '6 hours')
returns setof text
language plpgsql
set search_path = pg_catalog, haf_shared
as $$
declare
    _name text;
begin
    for _name in
        select r.database_name from haf_shared.run_databases r
        where r.created_at < now() - _ttl
        union
        select d.datname from pg_database d
        where d.datname like 'run\_%'
          and not exists (select 1 from haf_shared.run_databases r where r.database_name = d.datname)
    loop
        perform haf_shared._loopback('postgres', format('drop database if exists %I with (force)', _name));
        delete from haf_shared.run_databases where database_name = _name;
        return next _name;
    end loop;
    -- A clone commits its registration before creating the database, so give it a minute.
    delete from haf_shared.run_databases r
    where r.created_at < now() - interval '1 minute'
      and not exists (select 1 from pg_database d where d.datname = r.database_name);
end
$$;

-- What the service serves: the HAF commit, the template's head block and the
-- live run databases.
create or replace function haf_shared.health()
returns table (haf_commit text, template text, head_block bigint, seeded_at timestamptz, run_databases bigint)
language sql
stable
security definer
set search_path = pg_catalog, haf_shared
as $$
    select t.haf_commit, t.database_name, t.head_block, t.seeded_at,
           (select count(*) from pg_database d where d.datname like 'run\_%')
    from haf_shared.template t
$$;

revoke all on all functions in schema haf_shared from public;
revoke all on all tables in schema haf_shared from public;
grant usage on schema haf_shared to haf_shared_consumer;
grant execute on function haf_shared.clone_run_database(text), haf_shared.drop_run_database(text), haf_shared.health()
    to haf_shared_consumer;
