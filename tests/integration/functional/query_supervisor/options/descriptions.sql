DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __value TEXT;
BEGIN
    ASSERT ( SELECT COALESCE( short_desc, '' ) FROM pg_settings WHERE name = 'query_supervisor.limit_deletes' ) = 'Limited number of deleted rows', 'Limited number of deleted rows';
    ASSERT ( SELECT COALESCE( short_desc, '' ) FROM pg_settings WHERE name = 'query_supervisor.limit_inserts' ) = 'Limited number of inserted rows', 'Limit of rows that can be inserted with one query';
    ASSERT ( SELECT COALESCE( short_desc, '' ) FROM pg_settings WHERE name = 'query_supervisor.limits_enabled' ) = 'Are limits enabled', 'Are limits enabled';
    ASSERT ( SELECT COALESCE( short_desc, '' ) FROM pg_settings WHERE name = 'query_supervisor.limit_timeout' ) = 'Limited query time [ms]', 'Are limits enabled';
    ASSERT ( SELECT COALESCE( short_desc, '' ) FROM pg_settings WHERE name = 'query_supervisor.limit_tuples' ) = 'Limited number of tuples', 'Limited number of tuples';
    ASSERT ( SELECT COALESCE( short_desc, '' ) FROM pg_settings WHERE name = 'query_supervisor.limit_updates' ) = 'Limited number of updated rows', 'Limited number of updated rows';

    ASSERT ( SELECT COALESCE( extra_desc, '' ) FROM pg_settings WHERE name = 'query_supervisor.limit_deletes' ) = 'Limit of rows that can be deleted with one query', 'Limit of rows that can be deleted with one query';
    ASSERT ( SELECT COALESCE( extra_desc, '' ) FROM pg_settings WHERE name = 'query_supervisor.limit_inserts' ) = 'Limit of rows that can be inserted with one query', 'Limit of rows that can be inserted with one query';
    ASSERT ( SELECT COALESCE( extra_desc, '' ) FROM pg_settings WHERE name = 'query_supervisor.limits_enabled' ) = 'If limits are enabled', 'If limits are enabled';
    ASSERT ( SELECT COALESCE( extra_desc, '' ) FROM pg_settings WHERE name = 'query_supervisor.limit_timeout' ) = 'Limit of time for a query execution [ms]', 'Limit of time for a query execution [ms]';
    ASSERT ( SELECT COALESCE( extra_desc, '' ) FROM pg_settings WHERE name = 'query_supervisor.limit_tuples' ) = 'Limit of tuples which can be processed by the query', 'Limit of tuples which can be processed by the query';
    ASSERT ( SELECT COALESCE( extra_desc, '' ) FROM pg_settings WHERE name = 'query_supervisor.limit_updates' ) = 'Limit of rows that can be updated with one query', 'Limit of rows that can be updated with one query';
END
$BODY$
;
