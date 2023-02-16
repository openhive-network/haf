CREATE OR REPLACE FUNCTION hive.calculate_schema_hash(schema_name TEXT)
    RETURNS SETOF hive.verify_table_schema
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    schemarow    hive.verify_table_schema%ROWTYPE;
    _table_name     TEXT;
    _before_hash    TEXT;
    _columns   TEXT;
    _constraints   TEXT;
    _indexes    TEXT;
BEGIN
FOR _table_name IN SELECT table_name FROM hive.verified_tables_list ORDER BY table_name
LOOP
-- concatination of columns
    SELECT string_agg(c.agg_columns, ' | ') AS columns INTO _columns
    FROM 
    (SELECT 
    array_to_string(
        ARRAY[
            column_name, data_type], ', ', '* ') as agg_columns
    FROM 
    information_schema.columns 
    WHERE table_name=_table_name AND
    table_schema=schema_name 
    ORDER BY 
    column_name ASC) c;
    IF _columns IS NULL THEN
        _columns = 'EMPTY';
    END IF;

-- concatination of constraints

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

-- concatination of indexes

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

-- concatination of access rights

--    SELECT string_agg(ar.agg_access, ' | ') AS access INTO _access
--    FROM 
--    (SELECT 
--    array_to_string(
--        ARRAY[
--            grantor, grantee, privilege_type, is_grantable, with_hierarchy], ', ', '* ') as agg_access
--    FROM 
--    information_schema.role_table_grants 
--    WHERE table_name=_table_SELECT * FROM hive.create_database_hash('hive')name AND 
--    table_schema=schema_name
--    ORDER BY 
--    privilege_type ASC) ar;
--    IF _access IS NULL THEN
--        _access = 'EMPTY';
--    END IF;

    schemarow.table_name := _table_name;
    schemarow.table_schema := (_columns || _constraints || _indexes);
    schemarow.table_schema_hash := MD5(_columns || _constraints || _indexes)::uuid;
    schemarow.columns_hash := MD5(_columns)::uuid;
    schemarow.constraints_hash := MD5(_constraints)::uuid;
    schemarow.indexes_hash := MD5(_indexes)::uuid;
    schemarow.table_columns := _columns;
    schemarow.table_constraints := _constraints;
    schemarow.table_indexes := _indexes;
    RETURN NEXT schemarow;

    END LOOP;
RETURN;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_database_hash(schema_name TEXT)
    RETURNS SETOF hive.table_schema
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    ts hive.table_schema%ROWTYPE;
    _tmp TEXT;
BEGIN
    SELECT string_agg(table_schema, ' | ') FROM hive.calculate_schema_hash(schema_name) INTO _tmp GROUP BY table_name ORDER BY table_name ASC;
    ts.schema_name := schema_name;
    ts.schema_hash := MD5(_tmp)::uuid;
RETURN NEXT ts;
END;
$BODY$
;