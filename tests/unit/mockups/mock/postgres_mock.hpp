#pragma once

#include "psql_utils/postgres_includes.hpp"

#undef Max
#undef Assert

#include <gmock/gmock.h>

// mock-ed global variables
extern ExecutorStart_hook_type ExecutorStart_hook;
extern ExecutorRun_hook_type ExecutorRun_hook;
extern ExecutorFinish_hook_type ExecutorFinish_hook;
extern ExecutorEnd_hook_type ExecutorEnd_hook;
extern volatile sig_atomic_t QueryCancelPending;

// mock-ed hooks
void executorStartHook(QueryDesc* _queryDesc, int _eflags);
void executorRunHook(QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once);
void executorFinishHook(QueryDesc* _queryDesc);
void executorEndHook(QueryDesc* _queryDesc);

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
    virtual void table_close(Relation relation, LOCKMODE lockmode) = 0;
    virtual char *SPI_getrelname(Relation rel) = 0;

    virtual TimeoutId RegisterTimeout(TimeoutId id, timeout_handler_proc handler) = 0;
    virtual void disable_timeout(TimeoutId id, bool keep_indicator) = 0;
    virtual void standard_ExecutorStart(QueryDesc *queryDesc, int eflags) = 0;
    virtual void standard_ExecutorEnd(QueryDesc *queryDesc) = 0;
    virtual void standard_ExecutorRun(QueryDesc*, ScanDirection, uint64 , bool ) = 0;
    virtual void standard_ExecutorFinish(QueryDesc*) = 0;
    virtual void enable_timeout_after(TimeoutId, int) = 0;
    virtual void StatementCancelHandler(int) = 0;

    virtual void DefineCustomStringVariable(
      const char *,
      const char *,
      const char *,
      char **,
      const char *,
      GucContext,
      int,
      GucStringCheckHook,
      GucStringAssignHook,
      GucShowHook
    ) = 0;

    virtual void DefineCustomIntVariable(
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
    ) = 0;

    virtual char *GetConfigOption(const char*, bool, bool) = 0;
    virtual Oid GetSessionUserId() = 0;

    virtual void InstrAggNode(Instrumentation*, Instrumentation*) = 0;
    virtual Instrumentation *InstrAlloc(int n, int instrument_options, bool async_mode) = 0;
    //Bitmapset
    virtual int	bms_next_member(const Bitmapset* a, int prevbit) = 0;

    // Executor hooks
    virtual void executorStartHook(QueryDesc *queryDesc, int eflags) = 0;
    virtual void executorRunHook(QueryDesc *queryDesc, ScanDirection direction, uint64 count, bool execute_once) = 0;
    virtual void executorFinishHook(QueryDesc *queryDesc) = 0;
    virtual void executorEndHook(QueryDesc *queryDesc) = 0;


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
    MOCK_METHOD( void, table_close, (Relation, LOCKMODE) );
    MOCK_METHOD( char*, SPI_getrelname, (Relation) );

    MOCK_METHOD( TimeoutId, RegisterTimeout,(TimeoutId, timeout_handler_proc) );
    MOCK_METHOD( void, disable_timeout, (TimeoutId, bool) );
    MOCK_METHOD( void, standard_ExecutorStart, (QueryDesc*, int) );
    MOCK_METHOD( void, standard_ExecutorEnd, (QueryDesc*) );
    MOCK_METHOD( void, standard_ExecutorRun, (QueryDesc*, ScanDirection , uint64 , bool ) );
    MOCK_METHOD( void, standard_ExecutorFinish, (QueryDesc*) );
    MOCK_METHOD( void, enable_timeout_after, (TimeoutId, int) );


    MOCK_METHOD( void, DefineCustomStringVariable,(
        const char *,
        const char *,
        const char *,
        char **,
        const char *,
        GucContext,
        int,
        GucStringCheckHook,
        GucStringAssignHook,
        GucShowHook
        )
    );

    MOCK_METHOD( void, DefineCustomIntVariable, (
       const char*,
       const char*,
       const char*,
       int*,
       int,
       int,
       int,
       GucContext,
       int,
       GucIntCheckHook,
       GucIntAssignHook,
       GucShowHook
       )
    );

    MOCK_METHOD( char*, GetConfigOption, (const char*, bool, bool) );
    MOCK_METHOD( Oid, GetSessionUserId, () );

    MOCK_METHOD( void, InstrAggNode, (Instrumentation*, Instrumentation*) );
    MOCK_METHOD( Instrumentation*, InstrAlloc, (int, int, bool) );

    //Bitmapset
    MOCK_METHOD( int, bms_next_member, (const Bitmapset*, int));

    // Executor hooks
    MOCK_METHOD( void, executorStartHook, (QueryDesc*, int) );
    MOCK_METHOD( void, executorRunHook, (QueryDesc*, ScanDirection, uint64, bool) );
    MOCK_METHOD( void, executorFinishHook, (QueryDesc*) );
    MOCK_METHOD( void, executorEndHook, (QueryDesc*) );
    MOCK_METHOD( void, StatementCancelHandler, (int) );

    static std::shared_ptr<PostgresMock> create_and_get();

private:
    PostgresMock() = default;
};