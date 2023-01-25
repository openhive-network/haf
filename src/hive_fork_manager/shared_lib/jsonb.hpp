#pragma once
#include <fc/io/varint.hpp>

extern "C"
{
#include <utils/jsonb.h>
}

JsonbValue* variant_to_jsonb_value(const fc::variant& o);
