#pragma once

namespace fc
{
  class variant;
} /// namespace fc

struct JsonbValue;

struct JsonbValue* variant_to_jsonb_value(const fc::variant& o);
