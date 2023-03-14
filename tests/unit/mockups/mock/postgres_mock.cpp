#include "postgres_mock.hpp"

#include <cassert>
#include <memory>

namespace {
  // NOLINTNEXTLINE(fuchsia-statically-constructed-objects)
  std::weak_ptr< PostgresMock > POSTGRES_MOCK;
} // namespace

int SPI_result = SPI_ERROR_NOATTRIBUTE;

void executorStartHook(QueryDesc* _queryDesc, int _eflags) {
  assert(POSTGRES_MOCK.lock() && "No mock created, please execute first PostgresMock::create_and_get");

  return POSTGRES_MOCK.lock()->executorStartHook( _queryDesc, _eflags );
}

void executorRunHook(QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once) {
  assert(POSTGRES_MOCK.lock() && "No mock created, please execute first PostgresMock::create_and_get");

  return POSTGRES_MOCK.lock()->executorRunHook( _queryDesc, _direction, _count, _execute_once );
}
void executorFinishHook(QueryDesc* _queryDesc) {
  assert(POSTGRES_MOCK.lock() && "No mock created, plese execute first PostgresMock::create_and_get");

  return POSTGRES_MOCK.lock()->executorFinishHook( _queryDesc );
}

void executorEndHook(QueryDesc* _queryDesc) {
  assert(POSTGRES_MOCK.lock() && "No mock created, plese execute first PostgresMock::create_and_get");

  return POSTGRES_MOCK.lock()->executorEndHook( _queryDesc );
}


// mock-ed global variables
ExecutorStart_hook_type ExecutorStart_hook;
ExecutorRun_hook_type ExecutorRun_hook;
ExecutorFinish_hook_type ExecutorFinish_hook;
ExecutorEnd_hook_type ExecutorEnd_hook;

volatile sig_atomic_t QueryCancelPending;

MemoryContext CurrentMemoryContext = nullptr;


std::shared_ptr<PostgresMock> PostgresMock::create_and_get() {
  assert( POSTGRES_MOCK.lock() == nullptr && "Use only one mock instance" );
  auto instance = std::shared_ptr< PostgresMock >( new PostgresMock() );
  POSTGRES_MOCK = instance;
  return instance;
}

extern "C" {

Datum OidFunctionCall0Coll(Oid _functionId, Oid _collation) {
  assert(POSTGRES_MOCK.lock() && "No mock created, plese execute first PostgresMock::create_and_get");

  return POSTGRES_MOCK.lock()->OidFunctionCall0Coll(_functionId, _collation);
}

void getTypeBinaryOutputInfo(Oid _type, Oid* _typ_send, bool* _typ_is_var_len) {
  assert(POSTGRES_MOCK.lock() && "No mock created, plese execute first PostgresMock::create_and_get");

  return POSTGRES_MOCK.lock()->getTypeBinaryOutputInfo( _type, _typ_send, _typ_is_var_len );
}

void fmgr_info(Oid _function_id, FmgrInfo* _finfo) {
  assert(POSTGRES_MOCK.lock() && "No mock created, plese execute first PostgresMock::create_and_get");

  return POSTGRES_MOCK.lock()->fmgr_info( _function_id, _finfo );
}

bytea* SendFunctionCall(FmgrInfo* _flinfo, Datum _val) {
  assert(POSTGRES_MOCK.lock() && "No mock created, plese execute first PostgresMock::create_and_get");

  return POSTGRES_MOCK.lock()->SendFunctionCall( _flinfo, _val );
}


Bitmapset* get_primary_key_attnos(Oid _relid, bool _deferrable, Oid* _constraint) {
  return POSTGRES_MOCK.lock()->get_primary_key_attnos( _relid, _deferrable, _constraint );
}

int	bms_next_member(const Bitmapset* _a, int _prevbit) {
  return POSTGRES_MOCK.lock()->bms_next_member( _a, _prevbit );
}

void getTypeBinaryInputInfo(Oid _type, Oid* _typReceive, Oid* _typIOParam) {
  return POSTGRES_MOCK.lock()->getTypeBinaryInputInfo( _type, _typReceive, _typIOParam );
}

StringInfo makeStringInfo() {
  return POSTGRES_MOCK.lock()->makeStringInfo();
}

void appendBinaryStringInfo(StringInfo _str, const char* _data, int _datalen) {
  return POSTGRES_MOCK.lock()->appendBinaryStringInfo(_str, _data, _datalen);
}

Datum ReceiveFunctionCall(FmgrInfo *flinfo, fmStringInfo buf, Oid typioparam, int32 typmod) {
  return POSTGRES_MOCK.lock()->ReceiveFunctionCall(flinfo, buf, typioparam, typmod);
}

void getTypeOutputInfo(Oid type, Oid *typOutput, bool *typIsVarlena) {
  return POSTGRES_MOCK.lock()->getTypeOutputInfo(type, typOutput, typIsVarlena);
}

char* OidOutputFunctionCall(Oid functionId, Datum val) {
  return POSTGRES_MOCK.lock()->OidOutputFunctionCall(functionId, val);
}

void tuplestore_rescan(Tuplestorestate *state) {
  return POSTGRES_MOCK.lock()->tuplestore_rescan(state);
}

bool tuplestore_gettupleslot(Tuplestorestate *state, bool forward, bool copy, TupleTableSlot *slot) {
  return POSTGRES_MOCK.lock()->tuplestore_gettupleslot(state, forward, copy, slot);
}

RangeVar* makeRangeVar(char *schemaname, char *relname, int location) {
  return POSTGRES_MOCK.lock()->makeRangeVar(schemaname, relname, location);
}

Relation table_openrv(const RangeVar *relation, LOCKMODE lockmode) {
  return POSTGRES_MOCK.lock()->table_openrv(relation, lockmode);
}

void table_close(Relation relation, LOCKMODE lockmode) {
  return POSTGRES_MOCK.lock()->table_close(relation, lockmode);
}

char* SPI_getrelname(Relation rel) {
  return POSTGRES_MOCK.lock()->SPI_getrelname( rel );
}

TimeoutId RegisterTimeout(TimeoutId id, timeout_handler_proc handler) {
  return POSTGRES_MOCK.lock()->RegisterTimeout( id, handler );
}

void disable_timeout(TimeoutId id, bool keep_indicator) {
  return POSTGRES_MOCK.lock()->disable_timeout( id, keep_indicator );
}

void standard_ExecutorStart(QueryDesc *queryDesc, int eflags) {
  return POSTGRES_MOCK.lock()->standard_ExecutorStart( queryDesc, eflags );
}

void standard_ExecutorEnd(QueryDesc *queryDesc) {
  return POSTGRES_MOCK.lock()->standard_ExecutorEnd( queryDesc );
}

void standard_ExecutorRun(QueryDesc *queryDesc, ScanDirection direction, uint64 count, bool execute_once) {
  return POSTGRES_MOCK.lock()->standard_ExecutorRun( queryDesc, direction, count, execute_once );
}

void standard_ExecutorFinish(QueryDesc *queryDesc) {
  return POSTGRES_MOCK.lock()->standard_ExecutorFinish(queryDesc);
}

void enable_timeout_after(TimeoutId id, int delay_ms) {
  return POSTGRES_MOCK.lock()->enable_timeout_after(id,delay_ms);
}

void StatementCancelHandler(int _arg) {
  return POSTGRES_MOCK.lock()->StatementCancelHandler( _arg );
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
    return POSTGRES_MOCK.lock()->DefineCustomStringVariable(
      name, short_desc, long_desc, valueAddr, bootValue, context, flags, check_hook, assign_hook, show_hook
    );
  }

  const char *GetConfigOption(const char *name, bool missing_ok, bool restrict_privileged) {
    return POSTGRES_MOCK.lock()->GetConfigOption(name,missing_ok,restrict_privileged);
  }

  void InstrAggNode(Instrumentation *dst, Instrumentation *add) {
    return POSTGRES_MOCK.lock()->InstrAggNode(dst,add);
  }

  Instrumentation* InstrAlloc(int n, int instrument_options, bool async_mode) {
    return POSTGRES_MOCK.lock()->InstrAlloc( n,  instrument_options,  async_mode );
  }

} // extern "C"
