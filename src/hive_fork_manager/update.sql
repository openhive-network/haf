/**
  The file defines all things which are used only during update
 */

DROP SCHEMA IF EXISTS hive_update CASCADE;
CREATE SCHEMA hive_update;

/**
Easy way to save and recreate table or view dependencies, when you need to alter
something in them.
See http://pretius.com/postgresql-stop-worrying-about-table-and-view-dependencies/.
Enhanced by Wojciech Barcik wbarcik@syncad.com (handling of rules).
Modified to also store and restore object definition itself.
*/

CREATE OR REPLACE FUNCTION hive_update.deps_save_and_drop_dependencies(
    p_view_schema character varying,
    p_view_name character varying,
    drop_relation BOOLEAN DEFAULT true
)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE
AS $BODY$
/**
From http://pretius.com/postgresql-stop-worrying-about-table-and-view-dependencies/
@wojtek added DDL for rules.

Saves view and it's dependencies in table `deps_saved_ddl`, for
future restoration. Use function `deps_restore_dependencies` to restore them.
*/
declare
    v_curr record;
begin
    for v_curr in
        (
            select obj_schema, obj_name, obj_type from
                (
                    with recursive recursive_deps(obj_schema, obj_name, obj_type, depth) as
                                       (
                                           SELECT p_view_schema COLLATE "C", p_view_name COLLATE "C", relkind::VARCHAR, 0
                                           FROM pg_class
                                                    JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
                                           WHERE pg_namespace.nspname = p_view_schema AND pg_class.relname = p_view_name
                                           union
                                           select dep_schema::varchar, dep_name::varchar, dep_type::varchar,
                                                  recursive_deps.depth + 1 from
                                               (
                                                   select ref_nsp.nspname ref_schema, ref_cl.relname ref_name,
                                                          rwr_cl.relkind dep_type, rwr_nsp.nspname dep_schema,
                                                          rwr_cl.relname dep_name
                                                   from pg_depend dep
                                                            join pg_class ref_cl on dep.refobjid = ref_cl.oid
                                                            join pg_namespace ref_nsp on ref_cl.relnamespace = ref_nsp.oid
                                                            join pg_rewrite rwr on dep.objid = rwr.oid
                                                            join pg_class rwr_cl on rwr.ev_class = rwr_cl.oid
                                                            join pg_namespace rwr_nsp on rwr_cl.relnamespace = rwr_nsp.oid
                                                   where dep.deptype = 'n'
                                                     and dep.classid = 'pg_rewrite'::regclass
                                               ) deps
                                                   join recursive_deps on deps.ref_schema = recursive_deps.obj_schema
                                                   and deps.ref_name = recursive_deps.obj_name
                                           where (deps.ref_schema != deps.dep_schema or deps.ref_name != deps.dep_name)
                                       )
                    select obj_schema, obj_name, obj_type, depth
                    from recursive_deps
                    --  where depth > 0
                ) t
            group by obj_schema, obj_name, obj_type
            order by max(depth) desc
        ) loop

            insert into hafd.deps_saved_ddl(deps_view_schema, deps_view_name, deps_ddl_to_run)
            select p_view_schema, p_view_name, 'COMMENT ON ' ||
                                               case
                                                   when c.relkind = 'v' then 'VIEW'
                                                   when c.relkind = 'm' then 'MATERIALIZED VIEW'
                                                   else ''
                                                   end
                                                   || ' ' || n.nspname || '.' || c.relname || ' IS '''
                                                   || replace(d.description, '''', '''''') || ''';'
            from pg_class c
                     join pg_namespace n on n.oid = c.relnamespace
                     join pg_description d on d.objoid = c.oid and d.objsubid = 0
            where n.nspname = v_curr.obj_schema and c.relname = v_curr.obj_name
              and d.description is not null;

            insert into hafd.deps_saved_ddl(deps_view_schema, deps_view_name, deps_ddl_to_run)
            select p_view_schema, p_view_name, 'COMMENT ON COLUMN ' || n.nspname || '.'
                                                   || c.relname || '.' || a.attname || ' IS '''
                                                   || replace(d.description, '''', '''''') || ''';'
            from pg_class c
                     join pg_attribute a on c.oid = a.attrelid
                     join pg_namespace n on n.oid = c.relnamespace
                     join pg_description d on d.objoid = c.oid and d.objsubid = a.attnum
            where n.nspname = v_curr.obj_schema and c.relname = v_curr.obj_name
              and d.description is not null;

            insert into hafd.deps_saved_ddl(deps_view_schema, deps_view_name, deps_ddl_to_run)
            select p_view_schema, p_view_name, 'GRANT ' || privilege_type || ' ON '
                                                   || table_schema || '.' || table_name || ' TO ' || grantee
            from information_schema.role_table_grants
            where table_schema = v_curr.obj_schema and table_name = v_curr.obj_name;

            if v_curr.obj_type = 'v' then

                insert into hafd.deps_saved_ddl(deps_view_schema, deps_view_name, deps_ddl_to_run)
                select p_view_schema, p_view_name, definition
                from pg_catalog.pg_rules
                where schemaname = v_curr.obj_schema and tablename = v_curr.obj_name;

                insert into hafd.deps_saved_ddl(deps_view_schema, deps_view_name, deps_ddl_to_run)
                select p_view_schema, p_view_name, 'CREATE VIEW '
                                                       || v_curr.obj_schema || '.' || v_curr.obj_name || ' AS ' || view_definition
                from information_schema.views
                where table_schema = v_curr.obj_schema and table_name = v_curr.obj_name;

            elsif v_curr.obj_type = 'm' then
                insert into hafd.deps_saved_ddl(deps_view_schema, deps_view_name, deps_ddl_to_run)
                select p_view_schema, p_view_name, 'CREATE MATERIALIZED VIEW '
                                                       || v_curr.obj_schema || '.' || v_curr.obj_name || ' AS ' || definition
                from pg_matviews
                where schemaname = v_curr.obj_schema and matviewname = v_curr.obj_name;
            end if;

            if drop_relation = true then
                execute 'DROP ' ||
                        case
                            when v_curr.obj_type = 'v' then 'VIEW'
                            when v_curr.obj_type = 'm' then 'MATERIALIZED VIEW'
                            end
                            || ' ' || v_curr.obj_schema || '.' || v_curr.obj_name;
            end if;

        end loop;
end;
$BODY$;


CREATE OR REPLACE FUNCTION hive_update.deps_restore_dependencies(
    p_view_schema character varying,
    p_view_name character varying
)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE
AS $BODY$
/**
From http://pretius.com/postgresql-stop-worrying-about-table-and-view-dependencies/

Restores dependencies dropped by function `deps_save_and_drop_dependencies`.
*/
declare
    v_curr record;
begin
    for v_curr in
        (
            select deps_ddl_to_run
            from hafd.deps_saved_ddl
            where deps_view_schema = p_view_schema and deps_view_name = p_view_name
            order by deps_id desc
        ) loop
            execute v_curr.deps_ddl_to_run;
        end loop;
    delete from hafd.deps_saved_ddl
    where deps_view_schema = p_view_schema and deps_view_name = p_view_name;
end;
$BODY$;

CREATE TYPE hive_update.verify_table_schema AS(
   table_name TEXT,
   table_schema TEXT,
   table_schema_hash UUID,
   columns_hash UUID,
   constraints_hash UUID,
   indexes_hash UUID,
   table_columns TEXT,
   table_constraints TEXT,
   table_indexes TEXT
);

CREATE TYPE hive_update.state_provider_and_hash AS(
   provider hafd.state_providers,
   hash TEXT
);

DROP FUNCTION IF EXISTS hive_update.calculate_table_schema_hash;
CREATE FUNCTION hive_update.calculate_table_schema_hash(schema_name TEXT,_table_name TEXT)
    RETURNS hive_update.verify_table_schema
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    schemarow    hive_update.verify_table_schema;
    _columns   TEXT;
    _constraints   TEXT;
    _indexes    TEXT;
BEGIN
    SELECT string_agg(c.agg_columns, ' | ') AS columns INTO _columns
    FROM
        (SELECT
             array_to_string(
                     ARRAY[
                         column_name, data_type], ', ', '* ') as agg_columns
         FROM
             information_schema.columns isc
         WHERE table_name=_table_name AND
             table_schema=schema_name
         ORDER BY
             column_name ASC) c;
    IF _columns IS NULL THEN
        _columns = 'EMPTY';
    END IF;

-- concatenation of constraints

    SELECT string_agg(cc.agg_constraints, ' | ') AS columns INTO _constraints
    FROM
        (SELECT
             array_to_string(
                     ARRAY[
                         constraint_name, constraint_type, is_deferrable, initially_deferred, enforced], ', ', '* ') as agg_constraints
         FROM
             information_schema.table_constraints
         WHERE table_name=_table_name AND
             constraint_schema=schema_name AND
             NOT constraint_type='CHECK'
         ORDER BY
             constraint_name ASC) cc;
    IF _constraints IS NULL THEN
        _constraints = 'EMPTY';
    END IF;

-- concatenation of indexes

    SELECT string_agg(idx.agg_indexes, ' | ') AS indexes INTO _indexes
    FROM
        (SELECT
             array_to_string(
                     ARRAY[
                         t.relname,
                         i.relname,
                         a.attname], ', ', '* ') as agg_indexes
         from
             pg_class t,
             pg_class i,
             pg_index ix,
             pg_attribute a
         where
             t.oid = ix.indrelid
           and i.oid = ix.indexrelid
           and a.attrelid = t.oid
           and a.attnum = ANY(ix.indkey)
           and t.relkind = 'r'
           and t.relname like _table_name
           and t.relnamespace = (SELECT oid from pg_catalog.pg_namespace where nspname=schema_name)
         order by
             t.relname,
             i.relname,
             a.attname ASC) idx;
    IF _indexes IS NULL THEN
        _indexes = 'EMPTY';
    END IF;

    schemarow.table_name := _table_name;
    --    schemarow.table_schema := (_columns || _constraints || _indexes);
    schemarow.table_schema := (_columns);
    schemarow.table_schema_hash := MD5(_columns || _constraints || _indexes)::uuid;
    schemarow.columns_hash := MD5(_columns)::uuid;
    schemarow.constraints_hash := MD5(_constraints)::uuid;
    schemarow.indexes_hash := MD5(_indexes)::uuid;
    schemarow.table_columns := _columns;
    schemarow.table_constraints := _constraints;
    schemarow.table_indexes := _indexes;
    RETURN schemarow;
END;
$BODY$;

DROP FUNCTION IF EXISTS hive_update.calculate_state_provider_hash;
CREATE FUNCTION hive_update.calculate_state_provider_hash(_provider hafd.state_providers )
    RETURNS TEXT --md5 of start_provider function
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __md5     TEXT;
BEGIN
       -- to avoid complications with establish state providers and their tables ( it wil require
       -- to create artificial context and register state providers into it ), only hash of code
       -- which creates sp tables is taken into consideration
       EXECUTE format( 'SELECT MD5(pg_get_functiondef(''hive.start_provider_%s''::regproc))', _provider )
       INTO __md5;
       RETURN __md5;
END;
$BODY$;

DROP FUNCTION IF EXISTS hive_update.calculate_state_provider_hashes;
CREATE FUNCTION hive_update.calculate_state_provider_hashes( include_providers hafd.state_providers[] )
    RETURNS SETOF hive_update.state_provider_and_hash
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
BEGIN
    RETURN QUERY
        SELECT
              sp.* as provider
            , hive_update.calculate_state_provider_hash(sp.*) as hash
        FROM unnest(include_providers) as sp;
END;
$BODY$;



-- calculate hafd schema hash
DROP FUNCTION IF EXISTS hive_update.calculate_schema_hash;
CREATE FUNCTION hive_update.calculate_schema_hash()
    RETURNS SETOF hive_update.verify_table_schema
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
BEGIN

    RETURN QUERY SELECT (hive_update.calculate_table_schema_hash( 'hafd', ist.table_name)).*
    FROM information_schema.tables ist
    LEFT JOIN hafd.registered_tables hrt ON ist.table_name ILIKE hrt.shadow_table_name
    LEFT JOIN hafd.state_providers_registered spr ON ist.table_name ILIKE ANY( spr.tables )
    WHERE ist.table_schema = 'hafd'
    AND ist.table_type = 'BASE TABLE'
    AND hrt.shadow_table_name IS NULL -- is not a shadow table
    AND spr.tables IS NULL; -- is not a state provider table
END;
$BODY$
;

DROP FUNCTION IF EXISTS hive_update.create_database_hash;
CREATE FUNCTION hive_update.create_database_hash(include_providers hafd.state_providers[] = enum_range(NULL::hafd.state_providers))
    RETURNS UUID
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    _tmp TEXT;
    _provider_hashes TEXT;
BEGIN
    SELECT string_agg(table_schema, ' | ') FROM hive_update.calculate_schema_hash() INTO _tmp;
    SELECT string_agg(provider || hash, ' | ') FROM hive_update.calculate_state_provider_hashes(include_providers) INTO _provider_hashes;
    IF _provider_hashes IS NOT NULL THEN
        _tmp = _tmp || _provider_hashes;
    END IF;
    RETURN MD5(_tmp)::uuid;
END;
$BODY$
;

DROP FUNCTION IF EXISTS hive_update.get_used_state_providers;
CREATE FUNCTION hive_update.get_used_state_providers()
    RETURNS hafd.state_providers[]
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __result hafd.state_providers[];
BEGIN
    SELECT ARRAY_AGG( DISTINCT sp.state_provider ) INTO __result
    FROM hafd.state_providers_registered sp;

    RETURN COALESCE( __result, ARRAY[]::hafd.state_providers[] );
END;
$BODY$
;
