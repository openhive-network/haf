#pragma once

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
#include <postgres.h>
#include <catalog/pg_attribute.h>
#include <catalog/pg_authid.h>
#include <catalog/pg_constraint.h>
#include <catalog/pg_type.h>

#include <fmgr.h>
#include <foreign/foreign.h>
#include <funcapi.h>
#include <miscadmin.h>

#include <executor/executor.h>
#include <executor/spi.h>
#include <libpq-fe.h>
#include <access/table.h>
#include <access/sysattr.h>

#include <nodes/makefuncs.h>

#include <postmaster/bgworker.h>

#include <tcop/tcopprot.h>

#include <utils/array.h>
#include <utils/backend_status.h>
#include <utils/builtins.h>
#include <utils/catcache.h>
#include <utils/elog.h>
#include <utils/fmgrprotos.h>
#include <utils/fmgroids.h>
#include <utils/jsonb.h>
#include <utils/lsyscache.h>
#include <utils/timeout.h>
#include <utils/syscache.h>

#include <utils/rel.h>
#include <utils/tuplestore.h>

#include <pgstat.h>

#include <c.h>

}

#if defined(__clang__)
  #pragma clang diagnostic pop
#elif defined(__GNUC__) || defined(__GNUG__)
  #pragma GCC diagnostic pop
#endif

#ifdef elog
  // Undefine Postgres elog, please use ereport instead
  #undef elog
#endif
#ifdef POP_ELOG
  // Bring back fc elog
  #pragma pop_macro( "elog" )
  #undef POP_ELOG
#endif 


