
#include <hive/protocol/forward_impacted.hpp>

#include <fc/io/json.hpp>
#include <fc/string.hpp>

#include <vector>

using hive::protocol::account_name_type;
using hive::protocol::asset;

using hive::app::impacted_balance_data;

#define CUSTOM_LOG(format, ... ) { FILE *pFile = fopen("get-impacted-accounts.log","ae"); fprintf(pFile,format "\n",__VA_ARGS__); fclose(pFile); }

namespace // anonymous
{

std::string get_legacy_style_operation_impl( const std::string& operation_body )
{
  //hive::protocol::operation _op;
  //from_variant( fc::json::from_string( operation_body ), _op );

  return "TEST";
}

flat_set<account_name_type> get_accounts( const std::string& operation_body )
{
  hive::protocol::operation _op;
  from_variant( fc::json::from_string( operation_body ), _op );

  flat_set<account_name_type> _impacted;
  hive::app::operation_get_impacted_accounts( _op, _impacted );

  return _impacted;
}

impacted_balance_data collect_impacted_balances(const char* operation_body)
{
  hive::protocol::operation op;
  from_variant(fc::json::from_string(operation_body), op);

  return hive::app::operation_get_impacted_balances(op);
}

extern "C" void issue_error(const char* msg);

void issue_error(const std::string& msg)
{
  issue_error(msg.c_str());
}


} // namespace

extern "C"
{

#ifdef elog
#pragma push_macro( "elog" )
#undef elog
#endif

#include <include/psql_utils/postgres_includes.hpp>

#include <fmgr.h>
#include <catalog/pg_type.h>
#include <utils/builtins.h>
#include <utils/array.h>
#include <utils/lsyscache.h>

#include <funcapi.h>
#include <miscadmin.h>


void issue_error(const char* msg)
{
  ereport(ERROR, (errcode(ERRCODE_FEATURE_NOT_SUPPORTED), errmsg("%s", msg))); //NOLINT
}

#pragma pop_macro("elog")


PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(get_legacy_style_operation);

Datum get_legacy_style_operation(PG_FUNCTION_ARGS)
{
  #define NR_RETURN_ELEMENTS 1
  #define BODY_LEGACY_OP_IDX 0

  TupleDesc            retvalDescription;
  Tuplestorestate*     tupstore = nullptr;
  
  MemoryContext per_query_ctx;
  MemoryContext oldcontext;

  Datum tuple_values[NR_RETURN_ELEMENTS] = {0};
  bool  nulls[NR_RETURN_ELEMENTS] = {false};

  ReturnSetInfo* rsinfo = reinterpret_cast<ReturnSetInfo*>(fcinfo->resultinfo); //NOLINT

  /* check to see if caller supports us returning a tuplestore */
  if(rsinfo == nullptr || !IsA(rsinfo, ReturnSetInfo))
  {
    issue_error("set-valued function called in context that cannot accept a set");
  }

  if((rsinfo->allowedModes & SFRM_Materialize) == 0) //NOLINT
  {
    issue_error("materialize mode required, but it is not allowed in this context");
  }

/* Build a tuple descriptor for our result type */
  if(get_call_result_type(fcinfo, nullptr, &retvalDescription) != TYPEFUNC_COMPOSITE)
  {
    issue_error("return type must be a row type");
  }

  fc::string _body_legacy_op;
  const char* operation_body = text_to_cstring(PG_GETARG_TEXT_PP(0));

  try
  {
    _body_legacy_op = get_legacy_style_operation_impl( operation_body );
  }
  catch(const fc::exception& ex)
  {
    std::string exception_info = ex.to_string();
    issue_error(std::string("Broken get_impacted_balances() input argument: `") + operation_body + std::string("'. Error: ") + exception_info);
    return (Datum)0;
  }
  catch(const std::exception& ex)
  {
    issue_error(std::string("Broken get_impacted_balances() input argument: `") + operation_body + std::string("'. Error: ") + ex.what());
    return (Datum)0;
  }
  catch(...)
  {
    issue_error(std::string("Unknown error during processing get_impacted_balances(") + operation_body + std::string(")"));
    return (Datum)0;
  }

  per_query_ctx = rsinfo->econtext->ecxt_per_query_memory;
  oldcontext = MemoryContextSwitchTo(per_query_ctx);

  tupstore = tuplestore_begin_heap(true, false, work_mem);

  /* let the caller know we're sending back a tuplestore */
  rsinfo->returnMode = SFRM_Materialize;
  rsinfo->setResult = tupstore;
  rsinfo->setDesc = retvalDescription;

  MemoryContextSwitchTo(oldcontext);

  tuple_values[BODY_LEGACY_OP_IDX] = CStringGetTextDatum(_body_legacy_op.c_str());
  tuplestore_putvalues(tupstore, retvalDescription, tuple_values, nulls);

/* clean up and return the tuplestore */
  tuplestore_donestoring(tupstore);

  return (Datum)0;
}

PG_FUNCTION_INFO_V1(get_impacted_accounts);

Datum get_impacted_accounts(PG_FUNCTION_ARGS)
{
  FuncCallContext*  funcctx   = nullptr;

  try
  {
    int call_cntr = 0;
    int max_calls = 0;

    static Datum _empty = CStringGetTextDatum("");
    Datum current_account = _empty;

    bool _first_call = SRF_IS_FIRSTCALL();
    /* stuff done only on the first call of the function */
    if( _first_call )
    {
        MemoryContext   oldcontext;

        /* create a function context for cross-call persistence */
        funcctx = SRF_FIRSTCALL_INIT();

        /* switch to memory context appropriate for multiple function calls */
        oldcontext = MemoryContextSwitchTo(funcctx->multi_call_memory_ctx);

        /* total number of tuples to be returned */
        auto* _arg0 = (VarChar*)PG_GETARG_VARCHAR_P(0);
        auto* _op_body = (char*)VARDATA(_arg0);

        flat_set<account_name_type> _accounts = get_accounts( _op_body );

        funcctx->max_calls = _accounts.size();
        funcctx->user_fctx = nullptr;

        if( !_accounts.empty() )
        {
          auto itr = _accounts.begin();
          fc::string _str = *(itr);
          current_account = CStringGetTextDatum( _str.c_str() );

          if( _accounts.size() > 1 )
          {
            auto** _buffer = ( Datum** )palloc( ( _accounts.size() - 1 ) * sizeof( Datum* ) );
            for( size_t i = 1; i < _accounts.size(); ++i )
            {
              ++itr;
              _str = *(itr);

              _buffer[i - 1] = ( Datum* )palloc( sizeof( Datum ) );;
              *( _buffer[i - 1] ) = CStringGetTextDatum( _str.c_str() );
            }
            funcctx->user_fctx = _buffer;
          }
        }

        MemoryContextSwitchTo(oldcontext);
    }

    /* stuff done on every call of the function */
    funcctx = SRF_PERCALL_SETUP();

    call_cntr = funcctx->call_cntr;
    max_calls = funcctx->max_calls;

    if( call_cntr < max_calls )    /* do when there is more left to send */
    {
      if( !_first_call )
      {
        auto** _buffer = ( Datum** )funcctx->user_fctx;
        current_account = *( _buffer[ call_cntr - 1 ] );
      }

      SRF_RETURN_NEXT(funcctx, current_account );
    }
    else    /* do when there is no more left */
    {
      if( funcctx->user_fctx != nullptr )
      {
        auto** _buffer = ( Datum** )funcctx->user_fctx;

        for( auto i = 0; i < max_calls - 1; ++i ) {
          pfree( _buffer[i] );
        }

        pfree( _buffer );
      }

      SRF_RETURN_DONE(funcctx);
    }
  }
  catch(...)
  {
    try
    {
      auto* _arg0 = (VarChar*)PG_GETARG_VARCHAR_P(0);
      auto* _op_body = (char*)VARDATA(_arg0);

      CUSTOM_LOG( "An exception was raised during `get_impacted_accounts` call. Operation: %s", _op_body ? _op_body : "" )
    }
    catch(...)
    {
    }

    SRF_RETURN_DONE(funcctx);
  }
}

PG_FUNCTION_INFO_V1(get_impacted_balances);

/**
* CREATE TYPE impacted_balances_return AS
(
	account_name VARCHAR, -- Name of the account impacted by given operation  
	amount BIGINT, -- Amount of tokens changed by operation. Positive if account balance (specific to given asset_symbol_nai) should be incremented, negative if decremented
	asset_precision INT, -- Precision of assets (probably only for future cases when custom tokens will be available)
	asset_symbol_nai INT -- Type of asset symbol used in the operation
);

FUNCTION get_impacted_balances(_operation_body text) RETURNS SETOF impacted_balances_return
*/

Datum get_impacted_balances(PG_FUNCTION_ARGS)
{
  #define IMPACTED_BALANCES_RETURN_ATTRIBUTES 4
  #define ACCOUNT_NAME_IDX 0
  #define AMOUNT_IDX 1
  #define ASSET_PRECISION_IDX 2
  #define ASSET_NAI_IDX 3

  TupleDesc            retvalDescription;
  Tuplestorestate*     tupstore = nullptr;
  
  MemoryContext per_query_ctx;
  MemoryContext oldcontext;

  Datum tuple_values[IMPACTED_BALANCES_RETURN_ATTRIBUTES] = {0};
  bool  nulls[IMPACTED_BALANCES_RETURN_ATTRIBUTES] = {false};

  ReturnSetInfo* rsinfo = reinterpret_cast<ReturnSetInfo*>(fcinfo->resultinfo); //NOLINT

  /* check to see if caller supports us returning a tuplestore */
  if(rsinfo == nullptr || !IsA(rsinfo, ReturnSetInfo))
  {
    issue_error("set-valued function called in context that cannot accept a set");
  }

  if((rsinfo->allowedModes & SFRM_Materialize) == 0) //NOLINT
  {
    issue_error("materialize mode required, but it is not allowed in this context");
  }

/* Build a tuple descriptor for our result type */
  if(get_call_result_type(fcinfo, nullptr, &retvalDescription) != TYPEFUNC_COMPOSITE)
  {
    issue_error("return type must be a row type");
  }

  impacted_balance_data collected_data;
  const char* operation_body = text_to_cstring(PG_GETARG_TEXT_PP(0));

  try
  {
    collected_data = collect_impacted_balances(operation_body);
  }
  catch(const fc::exception& ex)
  {
    std::string exception_info = ex.to_string();
    issue_error(std::string("Broken get_impacted_balances() input argument: `") + operation_body + std::string("'. Error: ") + exception_info);
    return (Datum)0;
  }
  catch(const std::exception& ex)
  {
    issue_error(std::string("Broken get_impacted_balances() input argument: `") + operation_body + std::string("'. Error: ") + ex.what());
    return (Datum)0;
  }
  catch(...)
  {
    issue_error(std::string("Unknown error during processing get_impacted_balances(") + operation_body + std::string(")"));
    return (Datum)0;
  }

  per_query_ctx = rsinfo->econtext->ecxt_per_query_memory;
  oldcontext = MemoryContextSwitchTo(per_query_ctx);

  tupstore = tuplestore_begin_heap(true, false, work_mem);

  /* let the caller know we're sending back a tuplestore */
  rsinfo->returnMode = SFRM_Materialize;
  rsinfo->setResult = tupstore;
  rsinfo->setDesc = retvalDescription;

  MemoryContextSwitchTo(oldcontext);

  for(const auto& impacted_balance : collected_data)
  {
    fc::string account = impacted_balance.first;
    const hive::protocol::asset& balance_change = impacted_balance.second;
    const hive::protocol::asset_symbol_type& token_type = balance_change.symbol;

    tuple_values[ACCOUNT_NAME_IDX] = CStringGetTextDatum(account.c_str());

    tuple_values[AMOUNT_IDX] = Int64GetDatum(balance_change.amount.value);
    tuple_values[ASSET_PRECISION_IDX] = Int32GetDatum(int32_t(token_type.decimals()));
    tuple_values[ASSET_NAI_IDX] = Int32GetDatum(int32_t(token_type.to_nai()));

    tuplestore_putvalues(tupstore, retvalDescription, tuple_values, nulls);
  }

/* clean up and return the tuplestore */
  tuplestore_donestoring(tupstore);

  return (Datum)0;
}

}
