#include <psql_utils/postgres_includes.hpp>
#include <psql_utils/pg_cxx.hpp>

#include <hive/protocol/hive_custom_operations.hpp>
#include <hive/protocol/config.hpp>

#include <fc/io/json.hpp>
#include <fc/exception/exception.hpp>

extern "C"
{
#include "funcapi.h"
#include <utils/builtins.h>
#include <catalog/pg_type_d.h>
}

namespace {

// Parses delegate_rc operation from JSON array format: ["delegate_rc", {...}]
bool parse_delegate_rc_from_json(const char* json_text, hive::protocol::delegate_rc_operation& op)
{
  if (json_text == nullptr || *json_text == '\0')
    return false;

  try
  {
    fc::variant v = fc::json::from_string(json_text, fc::json::format_validation_mode::relaxed);

    // RC operations use array format: ["delegate_rc", {operation_data}]
    if (!v.is_array())
      return false;

    const fc::variants& arr = v.get_array();
    if (arr.size() != 2)
      return false;

    // First element must be "delegate_rc"
    if (!arr[0].is_string() || arr[0].as_string() != "delegate_rc")
      return false;

    // Second element is the operation data
    if (!arr[1].is_object())
      return false;

    fc::from_variant(arr[1], op);
    return true;
  }
  catch (const fc::exception&)
  {
    return false;
  }
  catch (const std::exception&)
  {
    return false;
  }
}

bool validate_delegate_rc_operation(const hive::protocol::delegate_rc_operation& op)
{
  try
  {
    if (op.delegatees.empty())
      return false;

    if (op.delegatees.size() > HIVE_RC_MAX_ACCOUNTS_PER_DELEGATION_OP)
      return false;

    if (op.max_rc < 0)
      return false;

    if (!hive::protocol::is_valid_account_name(op.from))
      return false;

    for (const auto& delegatee : op.delegatees)
    {
      if (delegatee == op.from)
        return false;

      if (!hive::protocol::is_valid_account_name(delegatee))
        return false;
    }

    return true;
  }
  catch (const std::exception&)
  {
    return false;
  }
}

} // anonymous namespace

extern "C"
{

PG_FUNCTION_INFO_V1(parse_rc_delegation);
Datum parse_rc_delegation(PG_FUNCTION_ARGS)
{
  FuncCallContext* funcctx;

  if (SRF_IS_FIRSTCALL())
  {
    funcctx = SRF_FIRSTCALL_INIT();
    MemoryContext oldcontext = MemoryContextSwitchTo(funcctx->multi_call_memory_ctx);

    TupleDesc tupdesc;
    if (get_call_result_type(fcinfo, NULL, &tupdesc) != TYPEFUNC_COMPOSITE)
    {
      ereport(ERROR,
        (errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
         errmsg("function returning record called in context that cannot accept type record")));
    }
    funcctx->tuple_desc = BlessTupleDesc(tupdesc);

    if (PG_ARGISNULL(0))
    {
      funcctx->max_calls = 0;
      MemoryContextSwitchTo(oldcontext);
      SRF_RETURN_DONE(funcctx);
    }

    text* json_text_arg = PG_GETARG_TEXT_PP(0);
    char* json_cstr = text_to_cstring(json_text_arg);

    hive::protocol::delegate_rc_operation* op = nullptr;
    bool parse_success = false;

    PsqlTools::PsqlUtils::pg_call_cxx([&]() {
      op = (hive::protocol::delegate_rc_operation*)
           MemoryContextAlloc(funcctx->multi_call_memory_ctx,
                              sizeof(hive::protocol::delegate_rc_operation));
      new (op) hive::protocol::delegate_rc_operation();

      parse_success = parse_delegate_rc_from_json(json_cstr, *op);
      if (parse_success)
      {
        parse_success = validate_delegate_rc_operation(*op);
      }
    }, ERRCODE_DATA_EXCEPTION);

    if (!parse_success || op == nullptr)
    {
      funcctx->max_calls = 0;
      MemoryContextSwitchTo(oldcontext);
      SRF_RETURN_DONE(funcctx);
    }

    funcctx->user_fctx = op;
    funcctx->max_calls = op->delegatees.size();

    MemoryContextSwitchTo(oldcontext);
  }

  funcctx = SRF_PERCALL_SETUP();

  if (funcctx->call_cntr < funcctx->max_calls)
  {
    hive::protocol::delegate_rc_operation* op =
      (hive::protocol::delegate_rc_operation*) funcctx->user_fctx;

    auto it = op->delegatees.begin();
    std::advance(it, funcctx->call_cntr);

    Datum values[3];
    bool nulls[3] = {false, false, false};

    values[0] = CStringGetTextDatum(static_cast<std::string>(op->from).c_str());
    values[1] = CStringGetTextDatum(static_cast<std::string>(*it).c_str());
    values[2] = Int64GetDatum(op->max_rc);

    HeapTuple tuple = heap_form_tuple(funcctx->tuple_desc, values, nulls);
    Datum result = HeapTupleGetDatum(tuple);

    SRF_RETURN_NEXT(funcctx, result);
  }
  else
  {
    SRF_RETURN_DONE(funcctx);
  }
}

} // extern "C"
