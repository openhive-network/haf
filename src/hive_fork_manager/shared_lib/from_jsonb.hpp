#pragma once
#include <hive/protocol/operations.hpp>

extern "C"
{
typedef Jsonb Jsonb;
}

hive::protocol::operation operation_from_jsonb_value(Jsonb* json);
