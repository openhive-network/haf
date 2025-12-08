#include <psql_utils/postgres_includes.hpp>

extern "C" {
#include <utils/timestamp.h>
}

extern "C"
{

/**
 * Vacuum a single shadow table.
 *
 * @param _table_name The name of the shadow table to vacuum (without schema prefix)
 */
PG_FUNCTION_INFO_V1(vacuum_shadow_table);
Datum vacuum_shadow_table(PG_FUNCTION_ARGS)
{
  text* table_name_text = PG_GETARG_TEXT_PP(0);
  char* table_name = text_to_cstring(table_name_text);

  ereport(NOTICE,
    (errmsg("vacuum_shadow_table: starting vacuum for table '%s'", table_name)));

  /*
   * This function is called from within Postgres transaction.
   * Vacuum can't be called in active transaction.
   * To workaround this, create a new db connection and use that to do vacuum.
   */
  Datum db_name_datum = OidFunctionCall0(F_CURRENT_DATABASE);
  const char* dbname = DatumGetCString(db_name_datum);
  if (dbname == NULL)
  {
    ereport(ERROR,
      (errcode(ERRCODE_INTERNAL_ERROR),
       errmsg("vacuum_shadow_table: could not get database name")));
  }

  char* conninfo = psprintf("dbname=%s user=postgres application_name=vacuum_shadow_table", dbname);

  PGconn* conn = PQconnectdb(conninfo);
  if (PQstatus(conn) != CONNECTION_OK)
  {
    char* err = pstrdup(PQerrorMessage(conn));
    PQfinish(conn);
    ereport(ERROR,
      (errcode(ERRCODE_CONNECTION_FAILURE),
       errmsg("vacuum_shadow_table: connection failed: %s", err)));
  }

  PG_TRY();
  {
    char* vacuum_cmd = psprintf("VACUUM FULL hafd.%s", table_name);

    TimestampTz start_time = GetCurrentTimestamp();
    PGresult* res = PQexec(conn, vacuum_cmd);
    TimestampTz end_time = GetCurrentTimestamp();
    ExecStatusType status = PQresultStatus(res);
    PQclear(res);

    if (status == PGRES_COMMAND_OK)
    {
      long secs;
      int usecs;
      TimestampDifference(start_time, end_time, &secs, &usecs);
      long elapsed_ms = secs * 1000L + usecs / 1000;

      ereport(NOTICE,
        (errmsg("vacuum_shadow_table: vacuumed hafd.%s in %ld ms",
                table_name, elapsed_ms)));

      PQfinish(conn);
      PG_RETURN_BOOL(true);
    }
    else
    {
      const char* err = PQerrorMessage(conn);
      ereport(WARNING,
        (errcode(ERRCODE_INTERNAL_ERROR),
         errmsg("vacuum_shadow_table: VACUUM failed for hafd.%s: %s",
                table_name, err)));
      PQfinish(conn);
      PG_RETURN_BOOL(false);
    }

  }
  PG_CATCH();
  {
    PQfinish(conn);
    PG_RE_THROW();
  }
  PG_END_TRY();

  PG_RETURN_BOOL(false);
}

} /* extern "C" */
