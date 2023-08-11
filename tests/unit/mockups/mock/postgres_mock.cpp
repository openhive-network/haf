// disable false-positives from siglongjmp security tests
#include "unfortified_sigjmp.h"

#include "postgres_mock.hpp"

#include <boost/scope_exit.hpp>

#include <cassert>
#include <memory>

namespace {
  // NOLINTNEXTLINE(fuchsia-statically-constructed-objects)
  std::weak_ptr<PostgresMock> POSTGRES_MOCK;

  /**
   * Global variables below and a macro EXECUTE_MOCK allow
   * to call mocked functions with handling possible errors
   * caused by non-returning pg_rethrow function which calls
   * are added to the code under test with Postgres error handling macros.
   * EXECUTE_MOCK correctly back to test stack after calling pg_rethrow
   * and correctly free an instance of PostgresMock. It is not
   * possible to use mocked pg_rethrow similar to other mock function since it
   * is declared as non-returning function. The only way to check if an error
   * was correctly handled by the code under test is to use macro EXPECT_PG_ERROR.
   * To thrown pg error in mocked postgres a call to ereport(ERROR, ...) should be made.
   *
   */
  sigjmp_buf STACK_FOR_PG_RETHROW_MOC{};
  std::shared_ptr<PostgresMock> BOTTOM_STACK_MOCK = nullptr;

#define EXECUTE_MOCK(function_call)                                          \
      if ( BOTTOM_STACK_MOCK ) { return BOTTOM_STACK_MOCK->function_call; }  \
      BOTTOM_STACK_MOCK = POSTGRES_MOCK.lock();                              \
      if ( sigsetjmp( STACK_FOR_PG_RETHROW_MOC, 0 ) == 0 ) {                 \
        BOOST_SCOPE_EXIT(void) {                                             \
          BOTTOM_STACK_MOCK = nullptr;                                       \
        } BOOST_SCOPE_EXIT_END                                               \
        return BOTTOM_STACK_MOCK->function_call;                             \
      }                                                                      \
      BOTTOM_STACK_MOCK.reset();                                             \
      siglongjmp( *PG_exception_stack, 1 );                                  \


} // namespace

int SPI_result = SPI_ERROR_NOATTRIBUTE;

void executorStartHook(QueryDesc* _queryDesc, int _eflags) {
  assert(POSTGRES_MOCK.lock() && "No mock created, please execute first PostgresMock::create_and_get");

  EXECUTE_MOCK( executorStartHook( _queryDesc, _eflags ) );
}

void executorRunHook(QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once) {
  assert(POSTGRES_MOCK.lock() && "No mock created, please execute first PostgresMock::create_and_get");

  EXECUTE_MOCK( executorRunHook( _queryDesc, _direction, _count, _execute_once ) );
}

void executorFinishHook(QueryDesc* _queryDesc) {
  assert(POSTGRES_MOCK.lock() && "No mock created, plese execute first PostgresMock::create_and_get");

  EXECUTE_MOCK(executorFinishHook( _queryDesc ));
}

void executorEndHook(QueryDesc* _queryDesc) {
  assert(POSTGRES_MOCK.lock() && "No mock created, plese execute first PostgresMock::create_and_get");

  EXECUTE_MOCK(executorEndHook( _queryDesc ));
}


// mock-ed global variables
ExecutorStart_hook_type ExecutorStart_hook;
ExecutorRun_hook_type ExecutorRun_hook;
ExecutorFinish_hook_type ExecutorFinish_hook;
ExecutorEnd_hook_type ExecutorEnd_hook;

volatile sig_atomic_t QueryCancelPending;

MemoryContext CurrentMemoryContext = nullptr;

BackgroundWorker bgWorker;
BackgroundWorker* MyBgworkerEntry = &bgWorker;

std::shared_ptr<PostgresMock> PostgresMock::create_and_get() {
  assert( POSTGRES_MOCK.lock() == nullptr && "Use only one mock instance" );
  auto instance = std::shared_ptr< PostgresMock >( new PostgresMock() );
  POSTGRES_MOCK = instance;
  return instance;
}

extern "C" {

Datum OidFunctionCall0Coll(Oid _functionId, Oid _collation) {
  assert(POSTGRES_MOCK.lock() && "No mock created, plese execute first PostgresMock::create_and_get");

  EXECUTE_MOCK(OidFunctionCall0Coll(_functionId, _collation));
}

void getTypeBinaryOutputInfo(Oid _type, Oid* _typ_send, bool* _typ_is_var_len) {
  assert(POSTGRES_MOCK.lock() && "No mock created, plese execute first PostgresMock::create_and_get");

  EXECUTE_MOCK(getTypeBinaryOutputInfo( _type, _typ_send, _typ_is_var_len ));
}

void fmgr_info(Oid _function_id, FmgrInfo* _finfo) {
  assert(POSTGRES_MOCK.lock() && "No mock created, plese execute first PostgresMock::create_and_get");

  EXECUTE_MOCK(fmgr_info( _function_id, _finfo ));
}

bytea* SendFunctionCall(FmgrInfo* _flinfo, Datum _val) {
  assert(POSTGRES_MOCK.lock() && "No mock created, plese execute first PostgresMock::create_and_get");

  EXECUTE_MOCK(SendFunctionCall( _flinfo, _val ));
}


Bitmapset* get_primary_key_attnos(Oid _relid, bool _deferrable, Oid* _constraint) {
  EXECUTE_MOCK(get_primary_key_attnos( _relid, _deferrable, _constraint ));
}

int	bms_next_member(const Bitmapset* _a, int _prevbit) {
  EXECUTE_MOCK(bms_next_member( _a, _prevbit ));
}

void getTypeBinaryInputInfo(Oid _type, Oid* _typReceive, Oid* _typIOParam) {
  EXECUTE_MOCK(getTypeBinaryInputInfo( _type, _typReceive, _typIOParam ));
}

StringInfo makeStringInfo() {
  EXECUTE_MOCK(makeStringInfo());
}

void appendBinaryStringInfo(StringInfo _str, const char* _data, int _datalen) {
  EXECUTE_MOCK(appendBinaryStringInfo(_str, _data, _datalen));
}

Datum ReceiveFunctionCall(FmgrInfo *flinfo, fmStringInfo buf, Oid typioparam, int32 typmod) {
  EXECUTE_MOCK(ReceiveFunctionCall(flinfo, buf, typioparam, typmod));
}

void getTypeOutputInfo(Oid type, Oid *typOutput, bool *typIsVarlena) {
  EXECUTE_MOCK(getTypeOutputInfo(type, typOutput, typIsVarlena));
}

char* OidOutputFunctionCall(Oid functionId, Datum val) {
  EXECUTE_MOCK(OidOutputFunctionCall(functionId, val));
}

void tuplestore_rescan(Tuplestorestate *state) {
  EXECUTE_MOCK(tuplestore_rescan(state));
}

bool tuplestore_gettupleslot(Tuplestorestate *state, bool forward, bool copy, TupleTableSlot *slot) {
  EXECUTE_MOCK(tuplestore_gettupleslot(state, forward, copy, slot));
}

RangeVar* makeRangeVar(char *schemaname, char *relname, int location) {
  EXECUTE_MOCK(makeRangeVar(schemaname, relname, location));
}

Relation table_openrv(const RangeVar *relation, LOCKMODE lockmode) {
  EXECUTE_MOCK(table_openrv(relation, lockmode));
}

void table_close(Relation relation, LOCKMODE lockmode) {
  EXECUTE_MOCK(table_close(relation, lockmode));
}

char* SPI_getrelname(Relation rel) {
  EXECUTE_MOCK(SPI_getrelname( rel ));
}

TimeoutId RegisterTimeout(TimeoutId id, timeout_handler_proc handler) {
  EXECUTE_MOCK(RegisterTimeout( id, handler ));
}

void disable_timeout(TimeoutId id, bool keep_indicator) {
  EXECUTE_MOCK(disable_timeout( id, keep_indicator ));
}

void standard_ExecutorStart(QueryDesc *queryDesc, int eflags) {
  EXECUTE_MOCK(standard_ExecutorStart( queryDesc, eflags ));
}

void standard_ExecutorEnd(QueryDesc *queryDesc) {
  EXECUTE_MOCK(standard_ExecutorEnd( queryDesc ));
}

void standard_ExecutorRun(QueryDesc *queryDesc, ScanDirection direction, uint64 count, bool execute_once) {
  EXECUTE_MOCK(standard_ExecutorRun( queryDesc, direction, count, execute_once ));
}

void standard_ExecutorFinish(QueryDesc *queryDesc) {
  EXECUTE_MOCK(standard_ExecutorFinish(queryDesc));
}

void enable_timeout_after(TimeoutId id, int delay_ms) {
  EXECUTE_MOCK(enable_timeout_after(id,delay_ms));
}

void StatementCancelHandler(int _arg) {
  EXECUTE_MOCK(StatementCancelHandler( _arg ));
}

void DefineCustomStringVariable(const char *name,
                                const char *short_desc,
                                const char *long_desc,
                                char **valueAddr,
                                const char *bootValue,
                                GucContext context,
                                int flags,
                                GucStringCheckHook check_hook,
                                GucStringAssignHook assign_hook,
                                GucShowHook show_hook
                                ) {
    EXECUTE_MOCK(DefineCustomStringVariable(
      name, short_desc, long_desc, valueAddr, bootValue, context, flags, check_hook, assign_hook, show_hook
    ));
  }

  void DefineCustomIntVariable(
    const char *name,
    const char *short_desc,
    const char *long_desc,
    int *valueAddr,
    int bootValue,
    int minValue,
    int maxValue,
    GucContext context,
    int flags,
    GucIntCheckHook check_hook,
    GucIntAssignHook assign_hook,
    GucShowHook show_hook
  ) {
    EXECUTE_MOCK(DefineCustomIntVariable(
      name, short_desc, long_desc, valueAddr, bootValue, minValue, maxValue, context, flags, check_hook, assign_hook, show_hook
    ));
  }

  void
  DefineCustomBoolVariable(
    const char *name,
    const char *short_desc,
    const char *long_desc,
    bool *valueAddr,
    bool bootValue,
    GucContext context,
    int flags,
    GucBoolCheckHook check_hook,
    GucBoolAssignHook assign_hook,
    GucShowHook show_hook
  ) {
    EXECUTE_MOCK(DefineCustomBoolVariable(
      name, short_desc, long_desc, valueAddr, bootValue, context, flags, check_hook, assign_hook, show_hook
    ));
  }

  const char *GetConfigOption(const char *name, bool missing_ok, bool restrict_privileged) {
    EXECUTE_MOCK(GetConfigOption(name,missing_ok,restrict_privileged));
  }

  Oid GetSessionUserId(void) {
    EXECUTE_MOCK(GetSessionUserId());
  }

void InstrAggNode(Instrumentation *dst, Instrumentation *add) {
    EXECUTE_MOCK(InstrAggNode(dst,add));
  }

  Instrumentation* InstrAlloc(int n, int instrument_options, bool async_mode) {
    EXECUTE_MOCK(InstrAlloc( n,  instrument_options,  async_mode ));
  }

  void pg_re_throw(void) {
    if ( !PG_exception_stack ) {
      std::cerr << "Unexpected pg error occur." << std::endl;
      abort();
    }
    siglongjmp( STACK_FOR_PG_RETHROW_MOC, 0 );
  }
} // extern "C"
