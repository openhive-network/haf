#pragma once

#include "operation_base.hpp"
#include <psql_utils/postgres_includes.hpp>

extern "C"
{

  // Create internal operation data type representation from the underlying bytea data
  _operation* make_operation( const char* raw_data, uint32 data_length );

  // compare underlying bytea _operation data using memcmp
  int operation_cmp_impl( const _operation* lhs, const _operation* rhs );

  // SQL functions

  /// operation casts
  Datum operation_to_jsonb( PG_FUNCTION_ARGS );

  Datum operation_from_jsonb( PG_FUNCTION_ARGS );

  Datum operation_from_jsontext( PG_FUNCTION_ARGS );

  Datum operation_to_jsontext( PG_FUNCTION_ARGS );

  Datum operation_in( PG_FUNCTION_ARGS );

  Datum operation_out( PG_FUNCTION_ARGS );

  Datum operation_bin_in_internal( PG_FUNCTION_ARGS );

  Datum operation_bin_in( PG_FUNCTION_ARGS );

  Datum operation_bin_out( PG_FUNCTION_ARGS );

  /// operation comparison
  Datum operation_eq( PG_FUNCTION_ARGS );

  Datum operation_ne( PG_FUNCTION_ARGS );

  Datum operation_gt( PG_FUNCTION_ARGS );

  Datum operation_ge( PG_FUNCTION_ARGS );

  Datum operation_lt( PG_FUNCTION_ARGS );

  Datum operation_le( PG_FUNCTION_ARGS );

  Datum operation_cmp( PG_FUNCTION_ARGS );

} /// extern "C"
