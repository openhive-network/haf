#pragma once
#include <hive/protocol/operations.hpp>

extern "C"
{
struct JsonbValue;
}

hive::protocol::operation operation_from_jsonb_value(const JsonbValue& json);
