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

            -- statements are restored in reverse order: the owner, then the privileges reset, then the grants in their original order
            insert into hafd.deps_saved_ddl(deps_view_schema, deps_view_name, deps_ddl_to_run)
            select p_view_schema, p_view_name, format('GRANT %s ON %I.%I TO %s%s', acl.privilege_type, n.nspname, c.relname,
                                                   case when acl.grantee = 0 then 'PUBLIC' else quote_ident(pg_get_userbyid(acl.grantee)) end,
                                                   case when acl.is_grantable then ' WITH GRANT OPTION' else '' end)
            from pg_class c
                     join pg_namespace n on n.oid = c.relnamespace
                     cross join lateral aclexplode(c.relacl) with ordinality as acl
            where n.nspname = v_curr.obj_schema and c.relname = v_curr.obj_name
            order by acl.ordinality desc;

            insert into hafd.deps_saved_ddl(deps_view_schema, deps_view_name, deps_ddl_to_run)
            select p_view_schema, p_view_name, format('REVOKE ALL ON %I.%I FROM PUBLIC, %I', n.nspname, c.relname, pg_get_userbyid(c.relowner))
            from pg_class c
                     join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = v_curr.obj_schema and c.relname = v_curr.obj_name and c.relacl is not null;

            insert into hafd.deps_saved_ddl(deps_view_schema, deps_view_name, deps_ddl_to_run)
            select p_view_schema, p_view_name, format('ALTER %s %I.%I OWNER TO %I',
                                                   case when c.relkind = 'm' then 'MATERIALIZED VIEW' else 'VIEW' end,
                                                   n.nspname, c.relname, pg_get_userbyid(c.relowner))
            from pg_class c
                     join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = v_curr.obj_schema and c.relname = v_curr.obj_name;

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
                select p_view_schema, p_view_name, pg_get_indexdef(i.indexrelid)
                from pg_index i
                         join pg_class c on c.oid = i.indrelid
                         join pg_namespace n on n.oid = c.relnamespace
                where n.nspname = v_curr.obj_schema and c.relname = v_curr.obj_name;

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

/**
Objects outside the extension that `DROP SCHEMA hive CASCADE`, which starts every update script,
would drop with the schema: the closure of pg_depend over normal, automatic and internal dependencies,
starting from the hive schema. An internal part (a view's rewrite rule, a row type) stands for the
object that owns it, and a column of a view for the whole view.
*/
CREATE OR REPLACE FUNCTION hive_update.find_hive_dependents()
    RETURNS TABLE( classid OID, objid OID, objsubid INTEGER, object_type TEXT, object_schema TEXT, object_identity TEXT )
    LANGUAGE sql
    STABLE
AS $BODY$
WITH RECURSIVE dropped( classid, objid, objsubid ) AS (
    SELECT 'pg_namespace'::regclass::oid, 'hive'::regnamespace::oid, 0
    UNION
    SELECT dependent.classid, dependent.objid, dependent.objsubid
    FROM dropped
    CROSS JOIN LATERAL (
        SELECT d.classid, d.objid, d.objsubid
        FROM pg_depend d
        WHERE d.refclassid = dropped.classid AND d.refobjid = dropped.objid
          AND ( dropped.objsubid = 0 OR d.refobjsubid = dropped.objsubid )
          AND d.deptype IN ( 'n', 'a', 'i' )
        UNION ALL
        SELECT d.refclassid, d.refobjid, 0
        FROM pg_depend d
        WHERE d.classid = dropped.classid AND d.objid = dropped.objid AND d.deptype = 'i'
    ) AS dependent
),
normalized AS (
    SELECT DISTINCT
        dropped.classid,
        dropped.objid,
        CASE WHEN dropped.classid = 'pg_class'::regclass AND c.relkind IN ( 'v', 'm' ) THEN 0 ELSE dropped.objsubid END AS objsubid
    FROM dropped
    LEFT JOIN pg_class c ON dropped.classid = 'pg_class'::regclass AND c.oid = dropped.objid
)
SELECT normalized.classid, normalized.objid, normalized.objsubid, o.type, s.object_schema, o.identity
FROM normalized
CROSS JOIN LATERAL pg_identify_object( normalized.classid, normalized.objid, normalized.objsubid ) AS o
CROSS JOIN LATERAL pg_identify_object_as_address( normalized.classid, normalized.objid, normalized.objsubid ) AS a
-- an object without a schema of its own (a column default, a trigger) is addressed by its table's schema first
CROSS JOIN LATERAL ( SELECT COALESCE( o.schema, a.object_names[ 1 ] ) AS object_schema ) AS s
WHERE s.object_schema NOT IN ( 'hive', 'hafd', 'hive_update', 'pg_toast' )
  AND NOT EXISTS (
      SELECT 1 FROM pg_depend part
      WHERE part.classid = normalized.classid AND part.objid = normalized.objid AND part.deptype = 'i'
  )
  AND NOT EXISTS (
      SELECT 1 FROM pg_depend member
      JOIN pg_extension e ON e.oid = member.refobjid AND e.extname = 'hive_fork_manager'
      WHERE member.classid = normalized.classid AND member.objid = normalized.objid
        AND member.refclassid = 'pg_extension'::regclass AND member.deptype = 'e'
  )
$BODY$;

/**
Saves a function or procedure in `deps_saved_ddl`, under its schema and signature, as one statement
list: its definition, owner, privileges and comment. Use function `deps_restore_dependencies` to restore it.
*/
CREATE OR REPLACE FUNCTION hive_update.deps_save_routine( _routine OID )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS $BODY$
DECLARE
    __kind TEXT;
    __signature TEXT := _routine::regprocedure::text;
BEGIN
    SELECT CASE WHEN p.prokind = 'p' THEN 'PROCEDURE' ELSE 'FUNCTION' END INTO __kind
    FROM pg_proc p
    WHERE p.oid = _routine;

    INSERT INTO hafd.deps_saved_ddl( deps_view_schema, deps_view_name, deps_ddl_to_run )
    SELECT
          n.nspname
        , left( format( '%s(%s)', p.proname, pg_get_function_identity_arguments( p.oid ) ), 255 )
        , concat_ws( E';\n'
            , pg_get_functiondef( p.oid )
            , format( 'ALTER %s %s OWNER TO %I', __kind, __signature, pg_get_userbyid( p.proowner ) )
            , CASE WHEN p.proacl IS NOT NULL THEN
                format( 'REVOKE ALL ON %s %s FROM PUBLIC, %I', __kind, __signature, pg_get_userbyid( p.proowner ) )
              END
            , (
                SELECT string_agg(
                      format( 'GRANT %s ON %s %s TO %s%s'
                        , acl.privilege_type
                        , __kind
                        , __signature
                        , CASE WHEN acl.grantee = 0 THEN 'PUBLIC' ELSE quote_ident( pg_get_userbyid( acl.grantee ) ) END
                        , CASE WHEN acl.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END )
                    , E';\n' ORDER BY acl.ordinality )
                FROM aclexplode( p.proacl ) WITH ORDINALITY AS acl
              )
            , CASE WHEN d.description IS NOT NULL THEN
                format( 'COMMENT ON %s %s IS %L', __kind, __signature, d.description )
              END
          )
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    LEFT JOIN pg_description d ON d.objoid = p.oid AND d.classoid = 'pg_proc'::regclass AND d.objsubid = 0
    WHERE p.oid = _routine;
END;
$BODY$;

/**
Saves in `deps_saved_ddl` every view, materialized view, function and procedure that the update would
drop with the hive schema (see `find_hive_dependents`). They are not dropped here: the update drops them,
and `restore_hive_dependents` recreates them afterwards. Raises an exception naming every other object
the update would drop, because it cannot be restored. Returns a line for each saved object.
*/
CREATE OR REPLACE FUNCTION hive_update.save_hive_dependents()
    RETURNS SETOF TEXT
    LANGUAGE plpgsql
    VOLATILE
AS $BODY$
DECLARE
    __unsupported TEXT;
    __object RECORD;
BEGIN
    CREATE TEMP TABLE hive_dependents ON COMMIT DROP AS
    SELECT d.*, c.relkind, p.prokind
    FROM hive_update.find_hive_dependents() d
    LEFT JOIN pg_class c ON d.classid = 'pg_class'::regclass AND c.oid = d.objid
    LEFT JOIN pg_proc p ON d.classid = 'pg_proc'::regclass AND p.oid = d.objid;

    SELECT string_agg( format( '%s %s', d.object_type, d.object_identity ), ', ' ORDER BY d.object_identity ) INTO __unsupported
    FROM hive_dependents d
    WHERE NOT COALESCE( d.relkind IN ( 'v', 'm' ) AND d.objsubid = 0, FALSE )
      AND NOT COALESCE( d.prokind IN ( 'f', 'p', 'w' ), FALSE )
      -- an index of a materialized view is saved with the view
      AND NOT EXISTS (
          SELECT 1 FROM pg_index i JOIN pg_class m ON m.oid = i.indrelid AND m.relkind = 'm'
          WHERE d.relkind = 'i' AND i.indexrelid = d.objid
      );

    IF __unsupported IS NOT NULL THEN
        RAISE EXCEPTION 'The update would drop objects that depend on the hive schema and cannot be restored: %', __unsupported
            USING HINT = 'Drop them before the update and recreate them after it.';
    END IF;

    -- deps_save_and_drop_dependencies also saves the views built on a view, so start from views built on no other saved view
    FOR __object IN
        SELECT v.object_schema, c.relname
        FROM hive_dependents v
        JOIN pg_class c ON c.oid = v.objid
        WHERE v.relkind IN ( 'v', 'm' )
          AND NOT EXISTS (
              SELECT 1
              FROM pg_rewrite r
              JOIN pg_depend dep ON dep.classid = 'pg_rewrite'::regclass AND dep.objid = r.oid AND dep.deptype = 'n'
              JOIN hive_dependents base ON base.classid = dep.refclassid AND base.objid = dep.refobjid AND base.relkind IN ( 'v', 'm' )
              WHERE r.ev_class = v.objid AND base.objid <> v.objid
          )
        ORDER BY v.object_identity
    LOOP
        PERFORM hive_update.deps_save_and_drop_dependencies( __object.object_schema::VARCHAR, __object.relname::VARCHAR, FALSE );
        RETURN NEXT format( 'Saving %s.%s', __object.object_schema, __object.relname );
    END LOOP;

    FOR __object IN
        SELECT r.objid, r.object_identity FROM hive_dependents r WHERE r.prokind IN ( 'f', 'p', 'w' ) ORDER BY r.object_identity
    LOOP
        PERFORM hive_update.deps_save_routine( __object.objid );
        RETURN NEXT format( 'Saving %s', __object.object_identity );
    END LOOP;
END;
$BODY$;

/**
Restores everything saved in `deps_saved_ddl`. An object whose restore fails is retried once the others
are restored, as it may need one of them (a function returning a view's row type, a view calling a function).
Raises an exception naming each object that still cannot be restored, so the update fails instead of losing it.
Returns a line for each restored object.
*/
CREATE OR REPLACE FUNCTION hive_update.restore_hive_dependents()
    RETURNS SETOF TEXT
    LANGUAGE plpgsql
    VOLATILE
AS $BODY$
DECLARE
    __saved RECORD;
    __restored_any BOOLEAN;
    __failures TEXT;
BEGIN
    LOOP
        __restored_any := FALSE;
        __failures := NULL;
        FOR __saved IN
            SELECT deps_view_schema AS object_schema, deps_view_name AS object_name
            FROM hafd.deps_saved_ddl
            GROUP BY deps_view_schema, deps_view_name
            ORDER BY max( deps_id ) DESC
        LOOP
            BEGIN
                PERFORM hive_update.deps_restore_dependencies( __saved.object_schema, __saved.object_name );
                __restored_any := TRUE;
                RETURN NEXT format( 'Restoring %s.%s', __saved.object_schema, __saved.object_name );
            -- any error: the next pass retries the object, and the exception below reports what still fails
            EXCEPTION WHEN OTHERS THEN
                __failures := concat_ws( E'\n', __failures, format( '%s.%s: %s', __saved.object_schema, __saved.object_name, SQLERRM ) );
            END;
        END LOOP;
        EXIT WHEN __failures IS NULL OR NOT __restored_any;
    END LOOP;

    IF __failures IS NOT NULL THEN
        RAISE EXCEPTION E'Could not restore objects that depend on the hive schema:\n%', __failures;
    END IF;
END;
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
    AND spr.tables IS NULL -- is not a state provider table
    ORDER BY ist.table_name;
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
