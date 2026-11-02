#include <cstdint>
#include <psql_utils/postgres_includes.hpp>
#include <psql_utils/pg_cxx.hpp>

#include <hive/protocol/hive_custom_operations.hpp>
#include <hive/protocol/config.hpp>
#include <hive/protocol/fixed_string.hpp>

#include <fc/io/json.hpp>
#include <fc/variant_object.hpp>
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

// hived's custom_json_evaluator applies operations of blocks it is not producing (nor validating as
// a new transaction) with fixed_string truncation verification disabled, so an account name longer
// than account_name_type's 16 bytes is cut to its first 16 bytes instead of being rejected
class truncating_account_names
{
  using truncation_controller = hive::protocol::details::truncation_controller;

public:
  truncating_account_names()
    : old_verify_status(truncation_controller::is_verifying_enabled())
  {
    truncation_controller::set_verify(false);
  }
  ~truncating_account_names() { truncation_controller::set_verify(old_verify_status); }

  truncating_account_names(const truncating_account_names&) = delete;
  truncating_account_names& operator=(const truncating_account_names&) = delete;

private:
  const bool old_verify_status;
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

// Legacy serialization names the op by its index in rc_custom_operation or by the name
// get_legacy_custom_operation_name gives it; delegate_rc_operation is the only (index 0) alternative
bool is_delegate_rc_legacy_name_or_id(const fc::variant& name_or_id)
{
  if (name_or_id.is_uint64())
    return name_or_id.as_uint64() == 0;
  return name_or_id.is_string() && name_or_id.as_string() == "delegate_rc";
}

// New serialization names the op by an integer (or bool) index, read with as_int64, or by the
// name get_custom_operation_name gives it
bool is_delegate_rc_type(const fc::variant& type)
{
  if (type.is_integer())
    return type.as_int64() == 0;
  return type.is_string() && type.as_string() == "delegate_rc_operation";
}

// Mirrors hived's custom_op_from_variant on a node that is not in control (replay, sync): extra
// array elements and extra object keys are ignored. An array of fewer than 2 elements leaves the
// default delegate_rc_operation, which fails validation, so it is rejected here.
// Returns false where hived would reject the operation.
bool parse_single_operation(const fc::variant& v, hive::protocol::delegate_rc_operation& op)
{
  const fc::variant* op_data = nullptr;

  if (v.is_array())
  {
    const fc::variants& arr = v.get_array();
    if (arr.size() < 2 || !is_delegate_rc_legacy_name_or_id(arr[0]))
      return false;
    op_data = &arr[1];
  }
  else if (v.is_object())
  {
    const fc::variant_object& obj = v.get_object();
    if (!obj.contains("type") || !obj.contains("value") || !is_delegate_rc_type(obj["type"]))
      return false;
    op_data = &obj["value"];
  }
  else
  {
    return false;
  }

  if (!op_data->is_object())
    return false;

  {
    const truncating_account_names truncating;
    fc::from_variant(*op_data, op);
  }

  return validate_delegate_rc_operation(op);
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

    std::vector<hive::protocol::delegate_rc_operation> ops;

    // A list is recognised by its first element being an array, as in hived's
    // generic_custom_operation_interpreter::apply; its later elements may use either serialization
    if (v.is_array() && v.size() > 0 && v.get_array()[0].is_array())
    {
      // hived validates every op of a list before applying any (apply_operations), and a failure
      // of one discards the whole list, so a single rejected element yields no rows
      for (const auto& op_variant : v.get_array())
      {
        ops.emplace_back();
        if (!parse_single_operation(op_variant, ops.back()))
          return rows;
      }
    }
    else
    {
      ops.emplace_back();
      if (!parse_single_operation(v, ops.back()))
        return rows;
    }

    for (const auto& op : ops)
    {
      for (const auto& delegatee : op.delegatees)
      {
        rc_delegation_row row;
        row.from_account = static_cast<std::string>(op.from);
        row.to_account = static_cast<std::string>(delegatee);
        row.max_rc = op.max_rc;
        rows.push_back(row);
      }
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
