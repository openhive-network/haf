#pragma once

extern "C"
{
#ifdef elog
#  pragma push_macro( "elog" )
#  undef elog
#endif

#include <include/psql_utils/postgres_includes.hpp>

#pragma pop_macro( "elog" )

  typedef struct
  {
    char vl_size_[VARHDRSZ];          /* varlena header (do not touch directly!) */
    char data[FLEXIBLE_ARRAY_MEMBER]; // raw operation data
  } _operation;

#define PG_RETURN_HIVE_OPERATION( x ) PG_RETURN_POINTER( x )

#define DatumGetHiveOperationPP( X )     ( (_operation*) PG_DETOAST_DATUM_PACKED( X ) )
#define PG_GETARG_HIVE_OPERATION_PP( n ) DatumGetHiveOperationPP( PG_GETARG_DATUM( n ) )

}
