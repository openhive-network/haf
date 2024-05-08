#pragma once

#include "l2_types.hpp"

#include <hive/protocol/operations.hpp>

extern "C"
{
struct JsonbValue;
}

hive::protocol::operation operation_from_jsonb_value(const JsonbValue& json);
l2::transaction transaction_from_jsonb_value(const JsonbValue& json);
l2::public_keys auths_from_jsonb_value(const JsonbValue& json);
