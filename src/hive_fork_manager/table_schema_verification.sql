CREATE OR REPLACE FUNCTION hive.calculate_table_schema_hash(schema_name TEXT,_table_name TEXT)
    RETURNS hafd.verify_table_schema
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    schemarow    hafd.verify_table_schema%ROWTYPE;
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

CREATE OR REPLACE FUNCTION hive.calculate_state_provider_schema_hash(schema_name TEXT, _provider hafd.state_providers )
    RETURNS SETOF hafd.verify_table_schema
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    _table_name     TEXT;
BEGIN
       PERFORM hive.context_create( _name =>'test_provider_hash', _schema =>schema_name );
       PERFORM hive.app_state_provider_import(_provider,'test_provider_hash');

       FOR _table_name IN SELECT UNNEST( tables ) FROM hafd.state_providers_registered WHERE state_provider = _provider ORDER BY id DESC LIMIT 1
       LOOP
               RETURN NEXT hive.calculate_table_schema_hash( schema_name, _table_name);
       END LOOP;

       PERFORM hive.app_state_provider_drop_all( 'test_provider_hash' );
       PERFORM hive.context_remove( 'test_provider_hash' );
       RETURN;
END;
$BODY$;



CREATE OR REPLACE FUNCTION hive.calculate_schema_hash(schema_name TEXT)
    RETURNS SETOF hafd.verify_table_schema
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    _table_name     TEXT;
    _state_provider hafd.state_providers;
    verified_tables_list TEXT[];
BEGIN

verified_tables_list = ARRAY[
'blocks',
'irreversible_data',
'transactions',
'transactions_multisig',
'operation_types',
'operations',
'applied_hardforks',
'accounts',
'account_operations',
'fork',
'blocks_reversible',
'transactions_reversible',
'transactions_multisig_reversible',
'operations_reversible',
'accounts_reversible',
'account_operations_reversible',
'applied_hardforks_reversible',
'contexts_attachment',
'contexts',
'contexts_log'
];

    FOR _table_name IN SELECT UNNEST( verified_tables_list ) as _table_name
    LOOP
        RETURN NEXT hive.calculate_table_schema_hash( schema_name, _table_name);
    END LOOP;

    FOR _state_provider IN SELECT unnest(enum_range(NULL::hafd.state_providers))
        LOOP
            RETURN NEXT hive.calculate_state_provider_schema_hash(schema_name,_state_provider);
        END LOOP;

    RETURN;

END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_database_hash(schema_name TEXT)
    RETURNS SETOF hafd.table_schema
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    ts hafd.table_schema%ROWTYPE;
    _tmp TEXT;
BEGIN
    TRUNCATE hafd.table_schema;

    SELECT string_agg(table_schema, ' | ') FROM hive.calculate_schema_hash(schema_name) INTO _tmp;

    INSERT INTO hafd.table_schema VALUES (schema_name, MD5(_tmp)::uuid);

    ts.schema_name := schema_name;
    ts.schema_hash := MD5(_tmp)::uuid;
RETURN NEXT ts;
END;
$BODY$
;

