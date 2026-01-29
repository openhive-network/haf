#include <psql_utils/postgres_includes.hpp>
#include <psql_utils/pg_cxx.hpp>

#include <hive/protocol/hive_custom_operations.hpp>
#include <hive/protocol/config.hpp>

#include <fc/io/json.hpp>
#include <fc/exception/exception.hpp>

#include <vector>

extern "C"
{
#include "funcapi.h"
#include <utils/builtins.h>
#include <catalog/pg_type_d.h>
}

namespace {

struct rc_delegation_row
{
  std::string from_account;
  std::string to_account;
  int64_t max_rc;
};

// Validates a single delegate_rc operation (stateless validation)
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

// Parses a single operation from variant and adds rows to result vector
// Returns true if it was a valid delegate_rc operation, false otherwise
bool parse_single_operation(const fc::variant& v, std::vector<rc_delegation_row>& rows)
{
  // Single operation format: ["delegate_rc", {operation_data}]
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

  hive::protocol::delegate_rc_operation op;
  fc::from_variant(arr[1], op);

  if (!validate_delegate_rc_operation(op))
    return false;

  // Add a row for each delegatee
  for (const auto& delegatee : op.delegatees)
  {
    rc_delegation_row row;
    row.from_account = static_cast<std::string>(op.from);
    row.to_account = static_cast<std::string>(delegatee);
    row.max_rc = op.max_rc;
    rows.push_back(row);
  }

  return true;
}

// Parses delegate_rc operations from JSON
// Handles both single operation and multiple operations formats
// Returns vector of delegation rows (empty if invalid/no delegate_rc ops)
std::vector<rc_delegation_row> parse_rc_delegations_from_json(const char* json_text)
{
  std::vector<rc_delegation_row> rows;

  if (json_text == nullptr || *json_text == '\0')
    return rows;

  try
  {
    fc::variant v = fc::json::from_string(json_text, fc::json::format_validation_mode::relaxed);

    if (!v.is_array() || v.size() == 0)
      return rows;

    const fc::variants& arr = v.get_array();

    // Check if first element is an array (multiple operations) or string (single operation)
    // This matches hived's generic_custom_operation_interpreter.hpp logic
    if (arr[0].is_array())
    {
      // Multiple operations format: [["delegate_rc", {...}], ["delegate_rc", {...}], ...]
      for (const auto& op_variant : arr)
      {
        // Parse each operation, ignoring non-delegate_rc operations
        parse_single_operation(op_variant, rows);
      }
    }
    else
    {
      // Single operation format: ["delegate_rc", {...}]
      parse_single_operation(v, rows);
    }
  }
  catch (const fc::exception&)
  {
    rows.clear();
  }
  catch (const std::exception&)
  {
    rows.clear();
  }

  return rows;
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

    std::vector<rc_delegation_row>* rows = nullptr;

    PsqlTools::PsqlUtils::pg_call_cxx([&]() {
      rows = new (MemoryContextAlloc(funcctx->multi_call_memory_ctx,
                                     sizeof(std::vector<rc_delegation_row>)))
             std::vector<rc_delegation_row>();

      *rows = parse_rc_delegations_from_json(json_cstr);
    }, ERRCODE_DATA_EXCEPTION);

    if (rows == nullptr || rows->empty())
    {
      funcctx->max_calls = 0;
      MemoryContextSwitchTo(oldcontext);
      SRF_RETURN_DONE(funcctx);
    }

    funcctx->user_fctx = rows;
    funcctx->max_calls = rows->size();

    MemoryContextSwitchTo(oldcontext);
  }

  funcctx = SRF_PERCALL_SETUP();

  if (funcctx->call_cntr < funcctx->max_calls)
  {
    std::vector<rc_delegation_row>* rows =
      (std::vector<rc_delegation_row>*) funcctx->user_fctx;

    const rc_delegation_row& row = (*rows)[funcctx->call_cntr];

    Datum values[3];
    bool nulls[3] = {false, false, false};

    values[0] = CStringGetTextDatum(row.from_account.c_str());
    values[1] = CStringGetTextDatum(row.to_account.c_str());
    values[2] = Int64GetDatum(row.max_rc);

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
