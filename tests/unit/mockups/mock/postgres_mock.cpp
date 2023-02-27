#include "postgres_mock.hpp"

#include <cassert>
#include <memory>

namespace {
  // NOLINTNEXTLINE(fuchsia-statically-constructed-objects)
  std::weak_ptr< PostgresMock > POSTGRES_MOCK;
} // namespace

int SPI_result = SPI_ERROR_NOATTRIBUTE;


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

TupleTableSlot* MakeTupleTableSlot() {
  return POSTGRES_MOCK.lock()->MakeTupleTableSlot();
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

Relation heap_openrv(const RangeVar *relation, LOCKMODE lockmode) {
  return POSTGRES_MOCK.lock()->heap_openrv(relation, lockmode);
}

void relation_close(Relation relation, LOCKMODE lockmode) {
  return POSTGRES_MOCK.lock()->relation_close(relation, lockmode);
}

char* SPI_getrelname(Relation rel) {
  return POSTGRES_MOCK.lock()->SPI_getrelname( rel );
}

} // extern "C"
