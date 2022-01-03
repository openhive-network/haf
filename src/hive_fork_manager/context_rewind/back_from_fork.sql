CREATE OR REPLACE FUNCTION hive.revert_insert( _table_schema TEXT, _table_name TEXT, _row_id BIGINT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    EXECUTE format(
          'DELETE FROM %I.%I WHERE hive_rowid = %s'
        , _table_schema
        , _table_name
        , _row_id
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.revert_delete( _table_schema TEXT, _table_name TEXT, _shadow_table_name TEXT, _operation_id BIGINT , _columns TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    EXECUTE format(
        'INSERT INTO %I.%I( %s )
        (
            SELECT %s
            FROM hive.%I st
            WHERE st.hive_operation_id = %s
        )'
        , _table_schema
        , _table_name
        , _columns
        , _columns
        , _shadow_table_name
        , _operation_id
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.revert_update( _table_schema TEXT, _table_name TEXT, _shadow_table_name TEXT, _operation_id BIGINT, _columns TEXT, _row_id BIGINT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
EXECUTE format(
    'UPDATE %I.%I as t SET ( %s ) = (
        SELECT %s
        FROM hive.%I st1
        WHERE st1.hive_operation_id = %s
    )
    WHERE t.hive_rowid = %s'
    , _table_schema
    , _table_name
    , _columns
    , _columns
    , _shadow_table_name
    , _operation_id
    , _row_id
    );
END;
$BODY$
;


DROP FUNCTION IF EXISTS hive.back_from_fork_one_table;
CREATE FUNCTION hive.back_from_fork_one_table( _table_schema TEXT, _table_name TEXT, _shadow_table_name TEXT, _columns TEXT[], _block_num_before_fork INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    EXECUTE format(
        'SELECT
        CASE st.hive_operation_type
            WHEN ''INSERT'' THEN hive.%I_%I_revert_insert( st.hive_rowid )
            WHEN ''DELETE'' THEN hive.%I_%I_revert_delete( st.hive_operation_id )
            WHEN ''UPDATE'' THEN hive.%I_%I_revert_update( st.hive_operation_id, st.hive_rowid )
        END
        FROM hive.%I st
        WHERE st.hive_block_num > %s
        ORDER BY st.hive_operation_id DESC'
        , _table_schema, _table_name
        , _table_schema, _table_name
        , _table_schema, _table_name
        , _shadow_table_name
        , _block_num_before_fork
    );

    -- remove rows from shadow table
    EXECUTE format( 'DELETE FROM hive.%I st WHERE st.hive_block_num > %s', _shadow_table_name, _block_num_before_fork );
END;
$BODY$
;

