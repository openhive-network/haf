#pragma once

extern "C"
{
#ifdef elog
#  pragma push_macro( "elog" )
#  undef elog
#endif

#include <include/psql_utils/postgres_includes.hpp>

#include <catalog/pg_type.h>
#include <fmgr.h>
#include <utils/array.h>
#include <utils/builtins.h>
#include <utils/lsyscache.h>

#include <funcapi.h>
#include <miscadmin.h>

#pragma pop_macro( "elog" )

#include "operation_base.hpp"

  // Create internal operation data type representation from the underlying bytea data
  _operation* make_operation( const char* raw_data, uint32 data_length );

  // compare underlying bytea _operation data using memcmp
  bool operation_equal( const _operation* lhs, const _operation* rhs );

  // SQL functions

  /// operation casts
  PG_FUNCTION_INFO_V1( operation_in );
  Datum operation_in( PG_FUNCTION_ARGS );

  PG_FUNCTION_INFO_V1( operation_out );
  Datum operation_out( PG_FUNCTION_ARGS );

  PG_FUNCTION_INFO_V1( operation_bin_in_internal );
  Datum operation_bin_in_internal( PG_FUNCTION_ARGS );

  PG_FUNCTION_INFO_V1( operation_bin_in );
  Datum operation_bin_in( PG_FUNCTION_ARGS );

  PG_FUNCTION_INFO_V1( operation_bin_out );
  Datum operation_bin_out( PG_FUNCTION_ARGS );

  /// operation comparison
  PG_FUNCTION_INFO_V1( operation_eq );
  Datum operation_eq( PG_FUNCTION_ARGS );

  PG_FUNCTION_INFO_V1( operation_ne );
  Datum operation_ne( PG_FUNCTION_ARGS );
}
