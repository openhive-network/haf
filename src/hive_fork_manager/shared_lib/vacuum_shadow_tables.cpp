#include <psql_utils/postgres_includes.hpp>

extern "C" {
#include <utils/timestamp.h>
}

extern "C"
{

/**
 * Vacuum shadow tables for registered application tables of a specific context.
 *
 * @param _context_name The name of the context whose shadow tables to vacuum
 */
PG_FUNCTION_INFO_V1(vacuum_shadow_tables);
Datum vacuum_shadow_tables(PG_FUNCTION_ARGS)
{
  int ret;
  uint64 processed_tables = 0;

  text* context_name_text = PG_GETARG_TEXT_PP(0);
  char* context_name = text_to_cstring(context_name_text);

  ereport(NOTICE,
    (errmsg("vacuum_shadow_tables: starting vacuum for context '%s'", context_name)));

  if (SPI_connect() != SPI_OK_CONNECT)
  {
    ereport(ERROR,
      (errcode(ERRCODE_INTERNAL_ERROR),
       errmsg("vacuum_shadow_tables: could not connect to SPI")));
  }

  Oid argtypes[1] = { TEXTOID };
  Datum values[1] = { CStringGetTextDatum(context_name) };

  ret = SPI_execute_with_args(
    "SELECT rt.shadow_table_name "
    "FROM hafd.registered_tables AS rt "
    "JOIN hafd.contexts AS c ON rt.context_id = c.id "
    "WHERE c.name = $1",
    1,      /* nargs */
    argtypes,
    values,
    NULL,   /* nulls */
    true,   /* read only */
    0       /* no limit */
  );

  if (ret != SPI_OK_SELECT)
  {
    SPI_finish();
    ereport(ERROR,
      (errcode(ERRCODE_INTERNAL_ERROR),
       errmsg("vacuum_shadow_tables: failed to query registered_tables")));
  }

  if (SPI_processed == 0)
  {
    SPI_finish();
    PG_RETURN_INT64(0);
  }

  char** shadow_tables = palloc_array(char*, SPI_processed);
  uint64 shadow_tables_count = 0;

  for (uint64 i = 0; i < SPI_processed; i++)
  {
    bool is_null;
    Datum val = SPI_getbinval(SPI_tuptable->vals[i],
                              SPI_tuptable->tupdesc,
                              1,
                              &is_null);
    if (!is_null)
    {
      shadow_tables[shadow_tables_count++] = TextDatumGetCString(val);
    }
  }

  SPI_finish();

  /*
   * This function is called from within Postgres transaction.
   * Vacuum can't be called in active transaction.
   * To workaround this, create a new db connection and use that to do vacuum.
   */
  const char* current_user = GetUserNameFromId(GetUserId(), false);
  Datum db_name_datum = OidFunctionCall0(F_CURRENT_DATABASE);
  const char* dbname = DatumGetCString(db_name_datum);
  if (dbname == NULL)
  {
    ereport(ERROR,
      (errcode(ERRCODE_INTERNAL_ERROR),
       errmsg("vacuum_shadow_tables: could not get database name")));
  }

  char* conninfo = psprintf("dbname=%s user=%s application_name=vacuum_shadow_tables",
                            dbname,
                            current_user);

  PGconn* conn = PQconnectdb(conninfo);
  if (PQstatus(conn) != CONNECTION_OK)
  {
    const char* err = PQerrorMessage(conn);
    PQfinish(conn);
    ereport(ERROR,
      (errcode(ERRCODE_CONNECTION_FAILURE),
       errmsg("vacuum_shadow_tables: connection failed: %s", err)));
  }

  PG_TRY();
  {
    for (uint64 i = 0; i < shadow_tables_count; ++i)
    {
      const char* table_name = shadow_tables[i];
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

        processed_tables++;
        ereport(NOTICE,
          (errmsg("vacuum_shadow_tables: vacuumed hafd.%s in %ld ms",
                  table_name, elapsed_ms)));
      }
      else
      {
        const char* err = PQerrorMessage(conn);
        ereport(WARNING,
          (errmsg("vacuum_shadow_tables: VACUUM failed for hafd.%s: %s",
                  table_name, err)));
      }
    }

    PQfinish(conn);

    ereport(NOTICE,
      (errmsg("vacuum_shadow_tables: vacuumed %lu shadow tables for context '%s'",
              processed_tables, context_name)));

    PG_RETURN_INT64(processed_tables);
  }
  PG_CATCH();
  {
    PQfinish(conn);
    PG_RE_THROW();
  }
  PG_END_TRY();

  PG_RETURN_INT64(processed_tables);
}

} /* extern "C" */
