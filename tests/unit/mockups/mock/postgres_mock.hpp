#pragma once

#include "include/psql_utils/postgres_includes.hpp"

#undef Max
#undef Assert

#include <gmock/gmock.h>



class IPostgresMock {
public:
    virtual ~IPostgresMock() = default;

    virtual Datum OidFunctionCall0Coll(Oid _functionId, Oid _collation) = 0;
    virtual void getTypeBinaryOutputInfo(Oid, Oid*, bool*) = 0;
    virtual void fmgr_info(Oid, FmgrInfo*) = 0;
    virtual bytea* SendFunctionCall(FmgrInfo *flinfo, Datum val) = 0;
    virtual Bitmapset *get_primary_key_attnos(Oid relid, bool deferrableOk, Oid *constraintOid) = 0;
    virtual void getTypeBinaryInputInfo(Oid _type, Oid* _typReceive, Oid* _typIOParam) = 0;
    virtual StringInfo makeStringInfo() = 0;
    virtual void appendBinaryStringInfo(StringInfo str, const char *data, int datalen) = 0;
    virtual Datum ReceiveFunctionCall(FmgrInfo *flinfo, fmStringInfo buf, Oid typioparam, int32 typmod) = 0;
    virtual void getTypeOutputInfo(Oid type, Oid *typOutput, bool *typIsVarlena) = 0;
    virtual char *OidOutputFunctionCall(Oid functionId, Datum val) = 0;
    virtual TupleTableSlot* MakeTupleTableSlot() = 0;
    virtual void tuplestore_rescan(Tuplestorestate *state) = 0;
    virtual bool tuplestore_gettupleslot(Tuplestorestate *state, bool forward, bool copy, TupleTableSlot *slot) = 0;
    virtual RangeVar* makeRangeVar(char *schemaname, char *relname, int location) = 0;
    virtual Relation table_openrv(const RangeVar *relation, LOCKMODE lockmode) = 0;
    virtual void relation_close(Relation relation, LOCKMODE lockmode) = 0;
    virtual char *SPI_getrelname(Relation rel) = 0;

    //Bitmapset
    virtual int	bms_next_member(const Bitmapset* a, int prevbit) = 0;

};

class PostgresMock : public IPostgresMock {
public:
    MOCK_METHOD( Datum, OidFunctionCall0Coll, (Oid, Oid) );
    MOCK_METHOD( void,  getTypeBinaryOutputInfo, (Oid, Oid*, bool*) );
    MOCK_METHOD( void, fmgr_info, (Oid, FmgrInfo*) );
    MOCK_METHOD( bytea*, SendFunctionCall, (FmgrInfo*, Datum) );
    MOCK_METHOD( Bitmapset*, get_primary_key_attnos, (Oid, bool, Oid*) );
    MOCK_METHOD( void, getTypeBinaryInputInfo, (Oid, Oid*, Oid*) );
    MOCK_METHOD( StringInfo, makeStringInfo, () );
    MOCK_METHOD( void, appendBinaryStringInfo, (StringInfo, const char *, int) );
    MOCK_METHOD( Datum, ReceiveFunctionCall, (FmgrInfo*, fmStringInfo, Oid, int32 ) );
    MOCK_METHOD( void, getTypeOutputInfo, (Oid, Oid*, bool*) );
    MOCK_METHOD( char*, OidOutputFunctionCall, (Oid, Datum) );
    MOCK_METHOD( TupleTableSlot*, MakeTupleTableSlot, () );
    MOCK_METHOD( void, tuplestore_rescan, (Tuplestorestate*) );
    MOCK_METHOD( bool, tuplestore_gettupleslot, (Tuplestorestate*, bool, bool, TupleTableSlot*) );
    MOCK_METHOD( RangeVar*, makeRangeVar, (char*, char*, int) );
    MOCK_METHOD( Relation, table_openrv, (const RangeVar*, LOCKMODE) );
    MOCK_METHOD( void, relation_close, (Relation, LOCKMODE) );
    MOCK_METHOD(  char*, SPI_getrelname, (Relation) );

    //Bitmapset
    MOCK_METHOD( int, bms_next_member, (const Bitmapset*, int));

    static std::shared_ptr<PostgresMock> create_and_get();

private:
    PostgresMock() = default;
};