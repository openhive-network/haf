#include "operation_base.hpp"

#include <include/psql_utils/postgres_includes.hpp>

#include <hive/protocol/operations.hpp>

#include <hive/protocol/forward_impacted.hpp>
#include <hive/protocol/misc_utilities.hpp>

#include <hive/plugins/block_api/block_api.hpp>

#include <fc/io/json.hpp>
#include <fc/string.hpp>

#include <vector>

using hive::protocol::account_name_type;
using hive::protocol::asset;
using hive::protocol::serialization_mode_controller;
using hive::protocol::transaction_serialization_type;

using hive::app::collected_keyauth_collection_t;
using hive::app::impacted_balance_data;

#define CUSTOM_LOG(format, ... ) { FILE *pFile = fopen("get-impacted-accounts.log","ae"); fprintf(pFile,format "\n" __VA_OPT__(,) __VA_ARGS__); fclose(pFile); }

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
    {
      T unpack_result;
      fc::raw::unpack_from_vector<T>(itr->second, unpack_result);
      result[pname] = fc::json::to_string(unpack_result);
    }
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

fc::string get_legacy_style_operation_impl( const hive::protocol::operation& _op )
{
  fc::variant v;
  fc::to_variant( _op, v );

  serialization_mode_controller::mode_guard guard( transaction_serialization_type::legacy );

  return fc::json::to_string( _op );
}

account_name_type get_created_from_account_create_operations_impl( const hive::protocol::operation& _op )
{
  return hive::app::get_created_from_account_create_operations( _op );
}

flat_set<account_name_type> get_accounts( const char* raw_data, uint32_t data_length )
{
  hive::protocol::operation _op;
  fc::raw::unpack_from_char_array( raw_data, data_length, _op );

  flat_set<account_name_type> _impacted;
  hive::app::operation_get_impacted_accounts( _op, _impacted );

  return _impacted;
}

impacted_balance_data collect_impacted_balances(const hive::protocol::operation& _op, const bool is_hf01)
{
  return hive::app::operation_get_impacted_balances(_op, is_hf01);
}

extern "C" void issue_error(const char* msg);

void issue_error(const fc::string& msg)
{
  issue_error(msg.c_str());
}

collected_keyauth_collection_t collect_keyauths(const hive::protocol::operation& op)
{
    return hive::app::operation_get_keyauths(op);
}

} // namespace

//use this template instead of Postgres' MemoryContextSwitchTo
template<typename T>
auto MemoryContextSwitcher(MemoryContext new_ctx, T statements) -> decltype(statements())
{
  class Switch
  {
  public:
    Switch(MemoryContext in): oldcontext(MemoryContextSwitchTo(in)){}
    ~Switch(){  MemoryContextSwitchTo(oldcontext);}
  private:
    MemoryContext oldcontext;
  };

  Switch switching_helper(new_ctx);
  return statements();
}

Tuplestorestate* init_tuple_store(ReturnSetInfo *rsinfo, TupleDesc retvalDescription)
{
  return MemoryContextSwitcher(rsinfo->econtext->ecxt_per_query_memory,
    [=](){
        Tuplestorestate *tupstore  = tuplestore_begin_heap(true, false, work_mem);
        rsinfo->returnMode = SFRM_Materialize;
        rsinfo->setResult = tupstore;
        rsinfo->setDesc = retvalDescription;
        return tupstore;
    }
  );
}


void check_return_mode(PG_FUNCTION_ARGS)
{
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
}

TupleDesc build_tuple_descriptor(PG_FUNCTION_ARGS)
{
  /* Build a tuple descriptor for our result type */
  TupleDesc retvalDescription;
  if(get_call_result_type(fcinfo, nullptr, &retvalDescription) != TYPEFUNC_COMPOSITE)
  {
    issue_error("return type must be a row type");
  }

  return retvalDescription;
}

#define HFM_NOEXCEPT_CAPTURE_AND_ISSUE_ERROR(ARG_VAL)                                                                          \
  catch(const fc::exception& ex)                                                                                               \
  {                                                                                                                            \
    std::string arg1;                                                                                                          \
    try                                                                                                                        \
    {                                                                                                                          \
      arg1 = ARG_VAL;                                                                                                          \
    }                                                                                                                          \
    catch(...)                                                                                                                 \
    {                                                                                                                          \
      arg1 = "[error retrieving arg1 value]";                                                                                  \
    }                                                                                                                          \
    fc::string exception_info = ex.to_string();                                                                                \
    issue_error(fc::string("Broken " + fc::string(C_function_name) + "()") + arg1 + fc::string(". Error: ") + exception_info); \
    return (Datum)0;                                                                                                           \
  }                                                                                                                            \
  catch(const std::exception& ex)                                                                                              \
  {                                                                                                                            \
    std::string arg1;                                                                                                          \
    try                                                                                                                        \
    {                                                                                                                          \
      arg1 = ARG_VAL;                                                                                                          \
    }                                                                                                                          \
    catch(...)                                                                                                                 \
    {                                                                                                                          \
      arg1 = "[error retrieving arg1 value]";                                                                                  \
    }                                                                                                                          \
    issue_error(fc::string("Broken " + fc::string(C_function_name) + "()") + arg1 + fc::string(". Error: ") + ex.what());      \
    return (Datum)0;                                                                                                           \
  }                                                                                                                            \
  catch(...)                                                                                                                   \
  {                                                                                                                            \
    std::string arg1;                                                                                                          \
    try                                                                                                                        \
    {                                                                                                                          \
      arg1 = ARG_VAL;                                                                                                          \
    }                                                                                                                          \
    catch(...)                                                                                                                 \
    {                                                                                                                          \
      arg1 = "[error retrieving arg1 value]";                                                                                  \
    }                                                                                                                          \
    issue_error(fc::string("Broken " + fc::string(C_function_name) + "()") + arg1 + fc::string(". Unknown error"));            \
    return (Datum)0;                                                                                                           \
  }

template<typename Collect, typename FillReturnTuple, typename ArgValueGetter>
Datum colect_data_and_fill_returned_recordset(Collect collect, FillReturnTuple fill_return_tuple,
  const char* C_function_name, ArgValueGetter arg_getter) noexcept
{
  try
  {
    collect();
  } HFM_NOEXCEPT_CAPTURE_AND_ISSUE_ERROR( fc::string(" input argument: '") + arg_getter() + "'" )

  try
  {
    fill_return_tuple();
  } HFM_NOEXCEPT_CAPTURE_AND_ISSUE_ERROR( ": fill_return_tuple invocation" )

  return (Datum)0;
}

template<typename Collect, typename FillReturnTuple>
Datum colect_operation_data_and_fill_returned_recordset(Collect collect,
  FillReturnTuple fill_return_tuple, const char* C_function_name, const char* raw_data, uint32_t data_length) noexcept
{
  try
  {
    using hive::protocol::operation;

    operation op = fc::raw::unpack_from_char_array< operation >( raw_data, data_length );

    return colect_data_and_fill_returned_recordset( [&]{
      collect(op);
    }, fill_return_tuple, C_function_name,
    [&op] {
      fc::variant v;
      fc::to_variant(op, v);

      return fc::json::to_string( v );
    } );
  } HFM_NOEXCEPT_CAPTURE_AND_ISSUE_ERROR( ": unpack_from_char_array invocation" )
}

template<typename ElemT, typename F>
void fill_record_field(Datum* tuple_values, ElemT elem, const F& func, std::size_t counter)
{
    *(tuple_values + counter) = func(elem);
}

template<typename ElemT, typename ... Funcs>
void fill_record(Datum* tuple_values, ElemT elem, Funcs ... funcs)
{
    std::size_t counter = 0;
    std::initializer_list<int>{ ( fill_record_field(tuple_values, elem, funcs, counter++), 0) ... };
}

template<typename Collection,typename ... Funcs>
void fill_return_tuples(const Collection& collection, PG_FUNCTION_ARGS, Funcs ... funcs)
{
    check_return_mode(fcinfo);

    TupleDesc retvalDescription = build_tuple_descriptor(fcinfo);

    ReturnSetInfo* rsinfo = reinterpret_cast<ReturnSetInfo*>(fcinfo->resultinfo); //NOLINT

    Tuplestorestate* tupstore = init_tuple_store(rsinfo, retvalDescription);

    const auto TUPLE_LENGTH = sizeof ... (Funcs);

    Datum tuple_values[TUPLE_LENGTH] = {0};
    bool nulls[TUPLE_LENGTH] = {false};

    for(const auto& collected_item : collection)
    {
      fill_record(tuple_values, collected_item, funcs...);

      tuplestore_putvalues(tupstore, retvalDescription, tuple_values, nulls);
    }

    tuplestore_donestoring(tupstore);

}


extern "C"
{


void issue_error(const char* msg)
{
  ereport(ERROR, (errcode(ERRCODE_FEATURE_NOT_SUPPORTED), errmsg("%s", msg))); //NOLINT
}

#pragma pop_macro("elog")



PG_FUNCTION_INFO_V1(get_created_from_account_create_operations);

Datum get_created_from_account_create_operations(PG_FUNCTION_ARGS)
{
  _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
  auto _result = (Datum)0;

  colect_operation_data_and_fill_returned_recordset(
    [=, &_result](const hive::protocol::operation& op)
    {
      std::string account = get_created_from_account_create_operations_impl( op );
      _result = CStringGetTextDatum( account.c_str() );
    },
    [](){},
    __FUNCTION__,
    VARDATA_ANY( op ), VARSIZE_ANY_EXHDR( op ));

  return _result;
}

PG_FUNCTION_INFO_V1(extract_set_witness_properties);

Datum extract_set_witness_properties(PG_FUNCTION_ARGS)
{

  extract_set_witness_properties_result_t _extracted_data;
  const char* _props_to_extract = text_to_cstring(PG_GETARG_TEXT_PP(0));

  colect_data_and_fill_returned_recordset(
      [=, &_extracted_data]()
      {
        extract_set_witness_properties_impl( _extracted_data, _props_to_extract );
      },

      [=, &_extracted_data]()
      {
        fill_return_tuples(_extracted_data, fcinfo, 
          [] (const auto& data) {return CStringGetTextDatum(data.first.c_str());},
          [] (const auto& data) {return CStringGetTextDatum(data.second.c_str());}
        );
      },

    __FUNCTION__,

     [=]{ return _props_to_extract; });

  return (Datum)0;
}

PG_FUNCTION_INFO_V1(get_legacy_style_operation);

Datum get_legacy_style_operation(PG_FUNCTION_ARGS)
{
  _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
  auto _result = (Datum)0;

  colect_operation_data_and_fill_returned_recordset(
    [=, &_result](const hive::protocol::operation& op)
    {
        fc::string _legacy_operation_body = get_legacy_style_operation_impl( op );
        _result = CStringGetTextDatum( _legacy_operation_body.c_str() );
    },
    [](){},
    __FUNCTION__,
    VARDATA_ANY( op ), VARSIZE_ANY_EXHDR( op ));

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
        /* create a function context for cross-call persistence */
        funcctx = SRF_FIRSTCALL_INIT();

        /* switch to memory context appropriate for multiple function calls */
        MemoryContextSwitcher(funcctx->multi_call_memory_ctx,
          [&current_account, fcinfo, funcctx]()
          {
            /* total number of tuples to be returned */
            _operation* _arg0 = PG_GETARG_HIVE_OPERATION_PP( 0 );

            flat_set<account_name_type> _accounts = get_accounts( VARDATA_ANY( _arg0 ), VARSIZE_ANY_EXHDR( _arg0 ) );

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
        }

      );

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
      CUSTOM_LOG( "An exception was raised during `get_impacted_accounts` call." );
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
  impacted_balance_data collected_data;
  _operation* operation_body = PG_GETARG_HIVE_OPERATION_PP( 0 );
  const bool is_hf01 = PG_GETARG_BOOL(1);

  colect_operation_data_and_fill_returned_recordset(

    [=, &collected_data](const hive::protocol::operation& op)
    {
        collected_data = collect_impacted_balances(op, is_hf01);
    }, 

    [=, &collected_data]()
    {
      fill_return_tuples(collected_data, fcinfo, 
          [] (const auto& impacted_balance) {fc::string account = impacted_balance.first; return CStringGetTextDatum(account.c_str());},
          [] (const auto& impacted_balance) {const hive::protocol::asset& balance_change = impacted_balance.second; return Int64GetDatum(balance_change.amount.value);},
          [] (const auto& impacted_balance) {const hive::protocol::asset_symbol_type& token_type = impacted_balance.second.symbol; return Int32GetDatum(int32_t(token_type.decimals()));},
          [] (const auto& impacted_balance) {const hive::protocol::asset_symbol_type& token_type = impacted_balance.second.symbol; return Int32GetDatum(int32_t(token_type.to_nai()));}
        );
    },
    
    __FUNCTION__,

    VARDATA_ANY( operation_body ), VARSIZE_ANY_EXHDR( operation_body ));



  return (Datum)0;
}

  PG_FUNCTION_INFO_V1(get_balance_impacting_operations);

  /**
   ** 
   **  CREATE OR REPLACE FUNCTION hive.get_balance_impacting_operations()
   ** 
   **
   **/

  Datum get_balance_impacting_operations(PG_FUNCTION_ARGS)
  {
    hive::app::stringset operations_used_in_get_balance_impacting_operations;
    
    colect_data_and_fill_returned_recordset
    (

      [=, &operations_used_in_get_balance_impacting_operations](){operations_used_in_get_balance_impacting_operations = hive::app::get_operations_used_in_get_balance_impacting_operations();},

      [=, &operations_used_in_get_balance_impacting_operations]()
      {
        fill_return_tuples(operations_used_in_get_balance_impacting_operations, fcinfo, 
          [] (const auto& operation_name) {return CStringGetTextDatum(operation_name.c_str());}
        );
      },

    __FUNCTION__,

      []{ return std::string{""}; }
    );
      

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
    _operation* operation_body = PG_GETARG_HIVE_OPERATION_PP( 0 );

    collected_keyauth_collection_t collected_keyauths;

    colect_operation_data_and_fill_returned_recordset(

      [=, &collected_keyauths](const hive::protocol::operation& op)
      {
        collected_keyauths = collect_keyauths(op);
      },


      [=, &collected_keyauths]()
      {
        fill_return_tuples(collected_keyauths, fcinfo,
          [] (const auto& collected_item) {return CStringGetTextDatum(collected_item.key_auth.c_str());},
          [] (const auto& collected_item) {return Int32GetDatum(collected_item.authority_kind);},
          [] (const auto& collected_item) {return CStringGetTextDatum(collected_item.account_name.c_str());}
        );
      },

      __FUNCTION__, 

      VARDATA_ANY( operation_body ), VARSIZE_ANY_EXHDR( operation_body )
    );

    return (Datum)0;
  }

  PG_FUNCTION_INFO_V1(is_keyauths_operation);

  Datum is_keyauths_operation(PG_FUNCTION_ARGS)
  {
    _operation* operation_body = PG_GETARG_HIVE_OPERATION_PP( 0 );

    bool _result = false;

    colect_operation_data_and_fill_returned_recordset(
      [=, &_result](const hive::protocol::operation& op)
      {
        _result = hive::app::is_keyauths_operation( op );
      },
      [](){},
      __FUNCTION__,
      VARDATA_ANY( operation_body ), VARSIZE_ANY_EXHDR( operation_body )
    );

    PG_RETURN_BOOL(_result);
  }

  PG_FUNCTION_INFO_V1(get_keyauths_operations);

  /**
   ** 
   **  CREATE OR REPLACE FUNCTION hive.get_keyauths_operations()
   **  RETURNS hive.get_operations_type
   **
   **
   ** To be used in a filter like this:
   **
   ** 'INSERT INTO hive.%s_keyauth 
   **     SELECT (hive.get_keyauths( ov.body )).*
   **     FROM hive.%s_operations_view ov
   **     WHERE
   **             hive.is_keyauths_operation(ov.body)
   **         AND 
   **             ov.block_num BETWEEN %s AND %s
   **     ON CONFLICT DO NOTHING'
   **     , _context, _context, _first_block, _last_block
   **
   **/

  Datum get_keyauths_operations(PG_FUNCTION_ARGS)
  {
    hive::app::stringset operations_used_in_get_keyauths;

    colect_data_and_fill_returned_recordset(

      [=, &operations_used_in_get_keyauths]()
      {
      operations_used_in_get_keyauths = hive::app::get_operations_used_in_get_keyauths();},

      [=, &operations_used_in_get_keyauths]()
      {
        fill_return_tuples(operations_used_in_get_keyauths, fcinfo, 
          [] (const auto& operation_name) {return CStringGetTextDatum(operation_name.c_str());}
        );
      },

      __FUNCTION__,

      []{ return std::string{""}; }
    );
      

    return (Datum)0;
  }  


PG_FUNCTION_INFO_V1(consume_json_block);

  /**
   ** 
   **  CREATE OR REPLACE FUNCTION hive.consume_json_block()
   **  RETURNS void
   **
   **
   **
   **/

void consume_json_block_impl(const char *json_block);

  Datum consume_json_block(PG_FUNCTION_ARGS)
  {



    const char *json_block = text_to_cstring(PG_GETARG_TEXT_PP(0));

    consume_json_block_impl(json_block);

    // colect_data_and_fill_returned_recordset(
    //   [=](){ hive::plugins::block_api::consume_json_block_impl(json_block);},
    //   [](){},
    //   __FUNCTION__,
    //   json_block);
    
    return (Datum)0;
  }  


PG_FUNCTION_INFO_V1(current_all_accounts_balances_C);

/**


CREATE OR REPLACE FUNCTION hive.current_all_accounts_balances_C();
RETURNS SETOF hive.current_account_balance_return_type
AS 'MODULE_PATHNAME', 'current_all_accounts_balances_C' LANGUAGE C;

use like this:
    insert into table_name select current_all_accounts_balances_C();

*/

Datum current_all_accounts_balances_C(PG_FUNCTION_ARGS)
{

  static int stop3 = 0;
  while(stop3)
  {
    int a = 0;
    a=a;
  }


  hive::app::collected_account_balances_collection_t collected_data;

  colect_data_and_fill_returned_recordset(

    [=, &collected_data]()
    {
        collected_data = hive::app::collect_current_all_accounts_balances();
    }, 

    [=, &collected_data]()
    {
      fill_return_tuples(collected_data, fcinfo, 
          [] (const auto& account_data) {fc::string account = account_data.account_name; return CStringGetTextDatum(account.c_str());},
          [] (const auto& account_data) { return Int64GetDatum(account_data.balance);}
        );
    },
    
    __FUNCTION__,

    "");

  return (Datum)0;
}



}
