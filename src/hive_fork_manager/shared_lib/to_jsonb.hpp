#pragma once
#include <hive/protocol/operations.hpp>

extern "C"
{
struct JsonbValue;
}

JsonbValue* operation_to_jsonb_value(const hive::protocol::operation& op);
