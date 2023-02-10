#pragma once
#include <hive/protocol/operations.hpp>

extern "C"
{
#include <utils/jsonb.h>
}

JsonbValue* operation_to_jsonb_value(const hive::protocol::operation& op);
