CREATE OR REPLACE FUNCTION hive.remove_obsolete_operations( _shadow_table_name TEXT, _irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
BEGIN
PERFORM hive.dlog('<no-context>', 'Entering remove_obsolete_operations');
EXECUTE format(
        'DELETE FROM hive.%I st WHERE st.hive_block_num <= %s'
    , _shadow_table_name
    , _irreversible_block
    );
    PERFORM hive.dlog('<no-context>', 'Exiting remove_obsolete_operations');
END;
$BODY$
;
