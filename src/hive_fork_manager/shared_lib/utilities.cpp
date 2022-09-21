
#include <hive/protocol/forward_impacted.hpp>
#include <hive/protocol/misc_utilities.hpp>

#include <fc/io/json.hpp>
#include <fc/string.hpp>

#include <vector>

using hive::protocol::account_name_type;
using hive::protocol::asset;
using hive::protocol::serialization_mode_controller;
using hive::protocol::transaction_serialization_type;

using hive::app::collected_keyauth_collection_t;
using hive::app::impacted_balance_data;

#define CUSTOM_LOG(format, ... ) { FILE *pFile = fopen("get-impacted-accounts.log","ae"); fprintf(pFile,format "\n",__VA_ARGS__); fclose(pFile); }

namespace // anonymous
{

using namespace hive::protocol;
using witness_set_properties_props_t = fc::flat_map< fc::string, std::vector< char > >;
using extract_set_witness_properties_result_t = fc::flat_map<fc::string, fc::string>;


struct wsp_fill_helper
{
  const witness_set_properties_props_t& source;
  extract_set_witness_properties_result_t& result;

  template<typename T>
  void try_fill(const fc::string& pname, const fc::string& alt_pname = fc::string{})
  {
    auto itr = source.find( pname );

    if( itr == source.end() && alt_pname != fc::string{} )
      itr = source.find( alt_pname );

    if(itr != source.end())
      result[pname] = fc::json::to_string(fc::raw::unpack_from_vector<T>(itr->second));
  }
};

void extract_set_witness_properties_impl(extract_set_witness_properties_result_t& output, const fc::string& _input)
{
  witness_set_properties_props_t input_properties{};
  fc::from_variant(fc::json::from_string(_input), input_properties);
  wsp_fill_helper helper{ input_properties, output };

  helper.try_fill<public_key_type>("key");
  helper.try_fill<asset>("account_creation_fee");
  helper.try_fill<uint32_t>("maximum_block_size");
  helper.try_fill<uint16_t>("hbd_interest_rate", "sbd_interest_rate");
  helper.try_fill<int32_t>("account_subsidy_budget");
  helper.try_fill<uint32_t>("account_subsidy_decay");
  helper.try_fill<public_key_type>("new_signing_key");
  helper.try_fill<price>("hbd_exchange_rate", "sbd_exchange_rate");
  helper.try_fill<fc::string>("url");
}

fc::string get_legacy_style_operation_impl( const fc::string& operation_body )
{
  hive::protocol::operation _op;
  from_variant( fc::json::from_string( operation_body ), _op );

  serialization_mode_controller::mode_guard guard( transaction_serialization_type::legacy );

  return fc::json::to_string( _op );
}

flat_set<account_name_type> get_accounts( const fc::string& operation_body )
{
  hive::protocol::operation _op;
  from_variant( fc::json::from_string( operation_body ), _op );

  flat_set<account_name_type> _impacted;
  hive::app::operation_get_impacted_accounts( _op, _impacted );

  return _impacted;
}

impacted_balance_data collect_impacted_balances(const char* operation_body, const bool is_hf01)
{
  hive::protocol::operation op;
  from_variant(fc::json::from_string(operation_body), op);

  return hive::app::operation_get_impacted_balances(op, is_hf01);
}

extern "C" void issue_error(const char* msg);

void issue_error(const fc::string& msg)
{
  issue_error(msg.c_str());
}

collected_keyauth_collection_t collect_keyauths(const char *operation_body)
{
    hive::protocol::operation op;
    from_variant(fc::json::from_string(operation_body), op);
    return hive::app::operation_get_keyauths(op);
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

PG_FUNCTION_INFO_V1(extract_set_witness_properties);

Datum extract_set_witness_properties(PG_FUNCTION_ARGS)
{
  #define EXTRACT_PROPERTIES_RETURN_ATTRIBUTES 2
  #define PROP_NAME 0
  #define PROP_VALUE 1


  TupleDesc            retvalDescription;
  Tuplestorestate*     tupstore = nullptr;

  MemoryContext per_query_ctx;
  MemoryContext oldcontext;

  Datum tuple_values[EXTRACT_PROPERTIES_RETURN_ATTRIBUTES] = {0};
  bool  nulls[EXTRACT_PROPERTIES_RETURN_ATTRIBUTES] = {false};

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

  extract_set_witness_properties_result_t _extracted_data;
  const char* _props_to_extract = text_to_cstring(PG_GETARG_TEXT_PP(0));

  try
  {
    extract_set_witness_properties_impl( _extracted_data, _props_to_extract );
  }
  catch(const fc::exception& ex)
  {
    fc::string exception_info = ex.to_string();
    issue_error(fc::string("Broken extract_set_witness_properties() input argument: `") + _props_to_extract + fc::string("'. Error: ") + exception_info);
    return (Datum)0;
  }
  catch(const std::exception& ex)
  {
    issue_error(fc::string("Broken extract_set_witness_properties() input argument: `") + _props_to_extract + fc::string("'. Error: ") + ex.what());
    return (Datum)0;
  }
  catch(...)
  {
    issue_error(fc::string("Unknown error during processing extract_set_witness_properties(") + _props_to_extract + fc::string(")"));
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

  for(const auto& data : _extracted_data)
  {
    tuple_values[PROP_NAME] = CStringGetTextDatum(data.first.c_str());
    tuple_values[PROP_VALUE] = CStringGetTextDatum(data.second.c_str());

    tuplestore_putvalues(tupstore, retvalDescription, tuple_values, nulls);
  }

/* clean up and return the tuplestore */
  tuplestore_donestoring(tupstore);

  return (Datum)0;
}

PG_FUNCTION_INFO_V1(get_legacy_style_operation);

Datum get_legacy_style_operation(PG_FUNCTION_ARGS)
{
  const char* _operation_body = text_to_cstring(PG_GETARG_TEXT_PP(0));
  auto _result = (Datum)0;

  try
  {

    fc::string _legacy_operation_body = get_legacy_style_operation_impl( _operation_body );

    _result = CStringGetTextDatum( _legacy_operation_body.c_str() );
  }
  catch(const fc::exception& ex)
  {
    fc::string exception_info = ex.to_string();
    issue_error(fc::string("Broken get_legacy_style_operation() input argument: `") + _operation_body + fc::string("'. Error: ") + exception_info);
    return (Datum)0;
  }
  catch(const std::exception& ex)
  {
    issue_error(fc::string("Broken get_legacy_style_operation() input argument: `") + _operation_body + fc::string("'. Error: ") + ex.what());
    return (Datum)0;
  }
  catch(...)
  {
    issue_error(fc::string("Unknown error during processing get_legacy_style_operation(") + _operation_body + fc::string(")"));
    return (Datum)0;
  }

  return _result;
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

FUNCTION get_impacted_balances(_operation_body text, IN _is_hf01 bool) RETURNS SETOF impacted_balances_return
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
  const bool is_hf01 = PG_GETARG_BOOL(1);

  try
  {
    collected_data = collect_impacted_balances(operation_body, is_hf01);
  }
  catch(const fc::exception& ex)
  {
    fc::string exception_info = ex.to_string();
    issue_error(fc::string("Broken get_impacted_balances() input argument: `") + operation_body + fc::string("'. Error: ") + exception_info);
    return (Datum)0;
  }
  catch(const std::exception& ex)
  {
    issue_error(fc::string("Broken get_impacted_balances() input argument: `") + operation_body + fc::string("'. Error: ") + ex.what());
    return (Datum)0;
  }
  catch(...)
  {
    issue_error(fc::string("Unknown error during processing get_impacted_balances(") + operation_body + fc::string(")"));
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


  PG_FUNCTION_INFO_V1(get_keyauths_wrapped);

  /**
   ** CREATE TYPE hive.authority_type AS ENUM( 'OWNER', 'ACTIVE', 'POSTING', 'WITNESS', 'NEW_OWNER_AUTHORITY', 'RECENT_OWNER_AUTHORITY');
   ** CREATE TYPE hive.keyauth_record_type AS
   **        (
   **              key_auth TEXT
   **            , authority_kind hive.authority_type
   **            , account_name TEXT
   **        );
   ** FUNCTION get_keyauths_wrapped(_operation_body text) RETURNS SETOF hive.keyauth_record_type
   **  It has to be wrapped, because it returns C enum as int. 
   **  Postgres then has to wrap it up to let postgresive enum enter postgress realm
   */



  Datum get_keyauths_wrapped(PG_FUNCTION_ARGS)
  {
  
    TupleDesc retvalDescription;
    Tuplestorestate *tupstore = nullptr;

    MemoryContext per_query_ctx;
    MemoryContext oldcontext;
  
    ReturnSetInfo *rsinfo = reinterpret_cast<ReturnSetInfo *>(fcinfo->resultinfo); 

    
    if (rsinfo == nullptr || !IsA(rsinfo, ReturnSetInfo))
    {
      issue_error("set-valued function called in context that cannot accept a set");
    }

    if ((rsinfo->allowedModes & SFRM_Materialize) == 0)
    {
      issue_error("materialize mode required, but it is not allowed in this context");
    }

 
    if (get_call_result_type(fcinfo, nullptr, &retvalDescription) != TYPEFUNC_COMPOSITE)
    {
      issue_error("return type must be a row type");
    }

    per_query_ctx = rsinfo->econtext->ecxt_per_query_memory;
    oldcontext = MemoryContextSwitchTo(per_query_ctx);

    tupstore = tuplestore_begin_heap(true, false, work_mem);

    rsinfo->returnMode = SFRM_Materialize;
    rsinfo->setResult = tupstore;
    rsinfo->setDesc = retvalDescription;

    MemoryContextSwitchTo(oldcontext);

    const char *operation_body = text_to_cstring(PG_GETARG_TEXT_PP(0));

    collected_keyauth_collection_t collected_keyauths;
    try
    {
      collected_keyauths = collect_keyauths(operation_body);
    }

    catch (const fc::exception &ex)
    {
      std::string exception_info = ex.to_string();
      issue_error(std::string("Broken ") + __FUNCTION__+  "() input argument: `" + operation_body + std::string("'. Error: ") + exception_info);
      return (Datum)0;
    }
    catch (const std::exception &ex)
    {
      issue_error(std::string("Broken ") + __FUNCTION__ + "() input argument: `" + operation_body + std::string("'. Error: ") + ex.what());
      return (Datum)0;
    }
    catch (...)
    {
      issue_error(std::string("Unknown error during processing ") + __FUNCTION__ + "(" + operation_body + std::string(")"));
      return (Datum)0;
    }
      
    const auto GET_KEYAUTHS_RETURN_ATTRIBUTES = 3;
    const auto KEY_AUTH_IDX = 0;
    const auto AUTHORITY_KIND_IDX = 1;
    const auto ACCOUNT_NAME__IDX = 2;

    Datum tuple_values[GET_KEYAUTHS_RETURN_ATTRIBUTES] = {0};
    bool nulls[GET_KEYAUTHS_RETURN_ATTRIBUTES] = {false};

    for(const auto& collected_item : collected_keyauths)
    {
      tuple_values[KEY_AUTH_IDX] = CStringGetTextDatum(collected_item.key_auth.c_str());
      tuple_values[AUTHORITY_KIND_IDX] = Int32GetDatum(collected_item.authority_kind);
      tuple_values[ACCOUNT_NAME__IDX] = CStringGetTextDatum(collected_item.account_name.c_str());
      tuplestore_putvalues(tupstore, retvalDescription, tuple_values, nulls);
    }

    tuplestore_donestoring(tupstore);
    return (Datum)0;
  }
}
