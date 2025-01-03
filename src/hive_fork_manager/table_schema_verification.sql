CREATE OR REPLACE FUNCTION hive.calculate_table_schema_hash(schema_name TEXT,_table_name TEXT)
    RETURNS hafd.verify_table_schema
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    schemarow    hafd.verify_table_schema;
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

CREATE OR REPLACE FUNCTION hive.calculate_state_provider_hash(_provider hafd.state_providers )
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

CREATE OR REPLACE FUNCTION hive.calculate_state_provider_hashes()
    RETURNS SETOF hafd.state_provider_and_hash
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
BEGIN
    RETURN QUERY
        SELECT
              sp.* as provider
            , hive.calculate_state_provider_hash(sp.*) as hash
        FROM unnest(enum_range(NULL::hafd.state_providers)) as sp;
END;
$BODY$;



-- calculate hafd schema hash
CREATE OR REPLACE FUNCTION hive.calculate_schema_hash()
    RETURNS SETOF hafd.verify_table_schema
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
BEGIN

    RETURN QUERY SELECT (hive.calculate_table_schema_hash( 'hafd', table_name)).*
    FROM information_schema.tables
    WHERE table_schema = 'hafd'
    AND table_type = 'BASE TABLE';
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_database_hash()
    RETURNS SETOF hafd.table_schema
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    ts hafd.table_schema%ROWTYPE;
    _tmp TEXT;
    _provider_hashes TEXT;
BEGIN
    TRUNCATE hafd.table_schema;

    SELECT string_agg(table_schema, ' | ') FROM hive.calculate_schema_hash() INTO _tmp;

    SELECT string_agg(provider || hash, ' | ') FROM hive.calculate_state_provider_hashes() INTO _provider_hashes;

    _tmp = _tmp || _provider_hashes;
    INSERT INTO hafd.table_schema VALUES ('hafd', MD5(_tmp)::uuid);

    ts.schema_name := 'hafd';
    ts.schema_hash := MD5(_tmp)::uuid;
RETURN NEXT ts;
END;
$BODY$
;

