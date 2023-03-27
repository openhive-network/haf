#pragma once

/* libpq-be.h header introduces name conflict with gtest regex, thus it needs to be excluded
 * from main postgres_includes.h header file
 */

#include "include/psql_utils/postgres_includes.hpp"

#ifdef elog
#pragma push_macro( "elog" )
#undef elog
#define POP_ELOG
#endif

//Suppress 'register' keyword usage warning in 3rd party code
#if defined(__clang__)
#pragma clang diagnostic push
  #pragma clang diagnostic ignored "-Wpadded"
#elif defined(__GNUC__) || defined(__GNUG__)
  #pragma GCC diagnostic push
  #pragma GCC diagnostic ignored "-Wregister"
  #pragma GCC diagnostic ignored "-Wunused-parameter"
#endif


extern "C" {

#ifdef ENABLE_GSS
  #pragma push_macro( "ENABLE_GSS" )
  #pragma push_macro( "REG_BADRPT" )
  #pragma push_macro( "REG_ESPACE" )
  #undef ENABLE_GSS
  #undef REG_BADRPT
  #include <libpq/libpq-be.h>
  #pragma push_macro( "REG_BADRPT" )
  #pragma pop_macro( "ENABLE_GSS" )
  #pragma pop_macro( "REG_ESPACE" )
#else
  #include <libpq/libpq-be.h>
#endif
}

#if defined(__clang__)
  #pragma clang diagnostic pop
#elif defined(__GNUC__) || defined(__GNUG__)
  #pragma GCC diagnostic pop
#endif

#ifdef POP_ELOG
#undef elog
  #pragma pop_macro( "elog" )
  #undef POP_ELOG
#endif


