#include "to_jsonb.hpp"

#include <psql_utils/postgres_includes.hpp>

#include <fc/exception/exception.hpp>
#include <fc/crypto/hex.hpp>

#include <hive/protocol/types_fwd.hpp>

#include <boost/container/flat_set.hpp>
#include <boost/container/flat_map.hpp>

#include <string>
#include <vector>

namespace {

JsonbValue* push_key_to_jsonb(const std::string& key, JsonbParseState** parseState)
{
  const char* str = key.c_str();
  const auto len = key.length();
  JsonbValue jb;
  jb.type = jbvString;
  jb.val.string.len = len;
  jb.val.string.val = pstrdup(str);
  return pushJsonbValue(parseState, WJB_KEY, &jb);
}

JsonbValue* push_string_to_jsonb(const std::string& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  const char* str = value.c_str();
  const auto len = value.length();
  JsonbValue jb;
  jb.type = jbvString;
  jb.val.string.len = len;
  jb.val.string.val = pstrdup(str);
  return pushJsonbValue(parseState, token, &jb);
}

JsonbValue* push_bool_to_jsonb(bool value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  JsonbValue jb;
  jb.type = jbvBool;
  jb.val.boolean = value;
  return pushJsonbValue(parseState, token, &jb);
}

JsonbValue* push_numeric_to_jsonb(const std::string& num, JsonbIteratorToken token, JsonbParseState** parseState)
{
  JsonbValue jb;
  jb.type = jbvNumeric;
  // Call the builtin Postgres function that converts text to numeric type.
  jb.val.numeric = DatumGetNumeric(DirectFunctionCall3(numeric_in,
      CStringGetDatum(num.c_str()),
      ObjectIdGetDatum(InvalidOid), // not used
      Int32GetDatum(-1))); // default type modifier
  return pushJsonbValue(parseState, token, &jb);
}

JsonbValue* push_uint64_to_jsonb(const uint64_t value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  // Numeric types are converted either to numeric or string types in json.
  // If value can be represented in 32bits, it's converted to numeric type.
  // Otherwise it's converted to string type.
  // This makes the operation::jsonb conversion in sync with the operation::text::jsonb conversion.
  if (value <= 0xffffffff)
  {
    return push_numeric_to_jsonb(std::to_string(value), token, parseState);
  }
  else
  {
    return push_string_to_jsonb(std::to_string(value), token, parseState);
  }
}
JsonbValue* push_int64_to_jsonb(const int64_t value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  // Numeric types are converted either to numeric or string types in json.
  // If value can be represented in 32bits, it's converted to numeric type.
  // Otherwise it's converted to string type.
  // This makes the operation::jsonb conversion in sync with the operation::text::jsonb conversion.
  if (value <= 0xffffffff)
  {
    return push_numeric_to_jsonb(std::to_string(value), token, parseState);
  }
  else
  {
    return push_string_to_jsonb(std::to_string(value), token, parseState);
  }
}

template<typename T>
void to_jsonb(const T& t, JsonbIteratorToken token, JsonbParseState** parseState);
void to_jsonb(bool value, JsonbIteratorToken token, JsonbParseState** parseState);
void to_jsonb(int16_t value, JsonbIteratorToken token, JsonbParseState** parseState);
void to_jsonb(int64_t value, JsonbIteratorToken token, JsonbParseState** parseState);
void to_jsonb(uint8_t value, JsonbIteratorToken token, JsonbParseState** parseState);
void to_jsonb(uint16_t value, JsonbIteratorToken token, JsonbParseState** parseState);
void to_jsonb(uint32_t value, JsonbIteratorToken token, JsonbParseState** parseState);
void to_jsonb(uint64_t value, JsonbIteratorToken token, JsonbParseState** parseState);
void to_jsonb(const std::string& value, JsonbIteratorToken token, JsonbParseState** parseState);
void to_jsonb(const std::vector<char>& value, JsonbIteratorToken token, JsonbParseState** parseState);
template<typename T>
void to_jsonb(const std::vector<T>& value, JsonbIteratorToken token, JsonbParseState** parseState);
template<typename A, typename B>
void to_jsonb(const std::pair<A, B>& value, JsonbIteratorToken token, JsonbParseState** parseState);
void to_jsonb(const hive::protocol::fixed_string<16>& value, JsonbIteratorToken token, JsonbParseState** parseState);
template<typename Storage>
void to_jsonb(const hive::protocol::fixed_string_impl<Storage>& value, JsonbIteratorToken token, JsonbParseState** parseState);
void to_jsonb(const hive::protocol::json_string& value, JsonbIteratorToken token, JsonbParseState** parseState);
void to_jsonb(const hive::protocol::asset& value, JsonbIteratorToken token, JsonbParseState** parseState);
void to_jsonb(const hive::protocol::legacy_asset& value, JsonbIteratorToken token, JsonbParseState** parseState);
void to_jsonb(const hive::protocol::legacy_hive_asset& value, JsonbIteratorToken token, JsonbParseState** parseState);
void to_jsonb(const hive::protocol::public_key_type& value, JsonbIteratorToken token, JsonbParseState** parseState);
template<typename T>
void to_jsonb(const fc::safe<T>& value, JsonbIteratorToken token, JsonbParseState** parseState);
template<typename T>
void to_jsonb(const fc::optional<T>& t, JsonbIteratorToken token, JsonbParseState** parseState);
template<typename... Types>
void to_jsonb(const fc::static_variant<Types...>& value, JsonbIteratorToken token, JsonbParseState** parseState);
template<typename T, size_t N>
void to_jsonb(const fc::array<T, N>& value, JsonbIteratorToken token, JsonbParseState** parseState);
void to_jsonb(const fc::time_point_sec& value, JsonbIteratorToken token, JsonbParseState** parseState);
void to_jsonb(const fc::ripemd160& value, JsonbIteratorToken token, JsonbParseState** parseState);
void to_jsonb(const fc::sha256& value, JsonbIteratorToken token, JsonbParseState** parseState);
template<typename T>
void to_jsonb(const boost::container::flat_set<T>& value, JsonbIteratorToken token, JsonbParseState** parseState);
template<typename T>
void to_jsonb(const flat_set_ex<T>& value, JsonbIteratorToken token, JsonbParseState** parseState);
template<typename K, typename... T>
void to_jsonb(const boost::container::flat_map<K, T...>& value, JsonbIteratorToken token, JsonbParseState** parseState);

template<typename T>
class member_to_jsonb_visitor
{
  public:
    member_to_jsonb_visitor(const T& obj, JsonbParseState** state) :
      obj(obj), parseState(state)
    {}

    template<typename Member, class Class, Member (Class::*member)>
    void operator()(const char* name) const
    {
      push_key_to_jsonb(name, parseState);
      to_jsonb(obj.*member, WJB_VALUE, parseState);
    }

  private:
    const T& obj;
    mutable JsonbParseState** parseState;
};

class static_variant_to_jsonb_visitor
{
  public:
    using result_type = JsonbValue*;

    static_variant_to_jsonb_visitor(JsonbParseState** state) : parseState(state)
    {}

    template<typename T>
    JsonbValue* operator()(const T& o) const
    {
      pushJsonbValue(parseState, WJB_BEGIN_OBJECT, NULL);
      // type
      const auto type_name = fc::trim_typename_namespace(fc::get_typename<T>::name());
      push_key_to_jsonb("type", parseState);
      push_string_to_jsonb(type_name, WJB_VALUE, parseState);
      // value
      push_key_to_jsonb("value", parseState);
      to_jsonb(o, WJB_VALUE, parseState);
      return pushJsonbValue(parseState, WJB_END_OBJECT, NULL);
    }

  private:
    mutable JsonbParseState** parseState;
};

template<typename T>
void to_jsonb(const T& t, JsonbIteratorToken token, JsonbParseState** parseState)
{
  pushJsonbValue(parseState, WJB_BEGIN_OBJECT, NULL);
  fc::reflector<T>::visit(member_to_jsonb_visitor<T>(t, parseState));
  pushJsonbValue(parseState, WJB_END_OBJECT, NULL);
}
void to_jsonb(bool value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  push_bool_to_jsonb(value, token, parseState);
}
void to_jsonb(int16_t value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  push_numeric_to_jsonb(std::to_string(value), token, parseState);
}
void to_jsonb(int64_t value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  push_int64_to_jsonb(value, token, parseState);
}
void to_jsonb(uint8_t value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  push_numeric_to_jsonb(std::to_string(value), token, parseState);
}
void to_jsonb(uint16_t value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  push_numeric_to_jsonb(std::to_string(value), token, parseState);
}
void to_jsonb(uint32_t value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  push_numeric_to_jsonb(std::to_string(value), token, parseState);
}
void to_jsonb(uint64_t value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  push_uint64_to_jsonb(value, token, parseState);
}
void to_jsonb(const std::string& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  push_string_to_jsonb(value, token, parseState);
}
void to_jsonb(const std::vector<char>& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  push_string_to_jsonb(fc::to_hex(value), token, parseState);
}
template<typename T>
void to_jsonb(const std::vector<T>& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  pushJsonbValue(parseState, WJB_BEGIN_ARRAY, NULL);
  for (const auto& elem : value)
  {
    to_jsonb(elem, WJB_ELEM, parseState);
  }
  pushJsonbValue(parseState, WJB_END_ARRAY, NULL);
}
template<typename A, typename B>
void to_jsonb(const std::pair<A, B>& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  pushJsonbValue(parseState, WJB_BEGIN_ARRAY, NULL);
  to_jsonb(value.first, WJB_ELEM, parseState);
  to_jsonb(value.second, WJB_ELEM, parseState);
  pushJsonbValue(parseState, WJB_END_ARRAY, NULL);
}
void to_jsonb(const hive::protocol::fixed_string<16>& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  const std::string str = static_cast<std::string>(value);
  JsonbValue jb;
  jb.type = jbvString;
  jb.val.string.len = str.length();
  jb.val.string.val = pstrdup(str.c_str());
  pushJsonbValue(parseState, token, &jb);
}
template<typename Storage>
void to_jsonb(const hive::protocol::fixed_string_impl<Storage>& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
    push_string_to_jsonb(std::string(value), token, parseState);
}
void to_jsonb(const hive::protocol::json_string& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  const std::string str = static_cast<std::string>(value);
  JsonbValue jb;
  jb.type = jbvString;
  jb.val.string.len = str.length();
  jb.val.string.val = pstrdup(str.c_str());
  pushJsonbValue(parseState, token, &jb);
}
void to_jsonb(const hive::protocol::asset& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  if(hive::protocol::serialization_mode_controller::legacy_enabled())
  {
    to_jsonb(hive::protocol::legacy_asset(value), token, parseState);
  }
  else
  {
    pushJsonbValue(parseState, WJB_BEGIN_OBJECT, NULL);
    const auto amount = boost::lexical_cast<std::string>(value.amount.value);
    const auto precision = std::to_string(value.symbol.decimals());
    const auto nai = value.symbol.to_nai_string();
    push_key_to_jsonb("amount", parseState);
    push_string_to_jsonb(amount, WJB_VALUE, parseState);
    push_key_to_jsonb("precision", parseState);
    push_numeric_to_jsonb(precision, WJB_VALUE, parseState);
    push_key_to_jsonb("nai", parseState);
    push_string_to_jsonb(nai, WJB_VALUE, parseState);
    pushJsonbValue(parseState, WJB_END_OBJECT, NULL);
  }
}
void to_jsonb(const hive::protocol::legacy_asset& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  push_string_to_jsonb(value.to_string(), token, parseState);
}
void to_jsonb(const hive::protocol::legacy_hive_asset& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  to_jsonb(value.to_asset<false>(), token, parseState);
}
void to_jsonb(const hive::protocol::public_key_type& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  to_jsonb(std::string(value), token, parseState);
}
template<typename T>
void to_jsonb(const fc::safe<T>& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  to_jsonb(value.value, token, parseState);
}
template<typename T>
void to_jsonb(const fc::optional<T>& t, JsonbIteratorToken token, JsonbParseState** parseState)
{
  if (t.valid())
  {
    to_jsonb(t.value(), token, parseState);
  }
}
template<typename T, size_t N>
void to_jsonb(const fc::array<T, N>& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  const auto vec = std::vector<char>( (const char*)&value, ((const char*)&value) + sizeof(value) );
  to_jsonb(vec, token, parseState);
}
template<typename... Types>
void to_jsonb(const fc::static_variant<Types...>& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  value.visit(static_variant_to_jsonb_visitor(parseState));
}
void to_jsonb(const fc::time_point_sec& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  push_string_to_jsonb(fc::string(value), token, parseState);
}
void to_jsonb(const fc::ripemd160& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  const auto vec = std::vector<char>( (const char*)&value, ((const char*)&value) + sizeof(value) );
  to_jsonb(vec, token, parseState);
}
void to_jsonb(const fc::sha256& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  const auto vec = std::vector<char>( (const char*)&value, ((const char*)&value) + sizeof(value) );
  to_jsonb(vec, token, parseState);
}
template<typename T>
void to_jsonb(const boost::container::flat_set<T>& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  pushJsonbValue(parseState, WJB_BEGIN_ARRAY, NULL);
  for (const auto& elem : value)
  {
    to_jsonb(elem, WJB_ELEM, parseState);
  }
  pushJsonbValue(parseState, WJB_END_ARRAY, NULL);
}
template<typename T>
void to_jsonb(const flat_set_ex<T>& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  to_jsonb(static_cast<boost::container::flat_set<T>>(value), token, parseState);
}
template<typename K, typename... T>
void to_jsonb(const boost::container::flat_map<K, T...>& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  pushJsonbValue(parseState, WJB_BEGIN_ARRAY, NULL);
  for (const auto& kv : value)
  {
    to_jsonb(kv, WJB_ELEM, parseState);
  }
  pushJsonbValue(parseState, WJB_END_ARRAY, NULL);
}

}

JsonbValue* operation_to_jsonb_value(const hive::protocol::operation& op)
{
  JsonbParseState* parseState = nullptr;

  return op.visit(static_variant_to_jsonb_visitor(&parseState));
}
