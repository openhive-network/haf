#include <psql_utils/postgres_includes.hpp>

#include <hive/protocol/operations.hpp>

#include <map>
#include <string>

template <typename Storage>
void set_member(hive::protocol::fixed_string_impl<Storage>& member, const JsonbValue& json);
void set_member(hive::protocol::json_string& member, const JsonbValue& json);
void set_member(std::string& member, const JsonbValue& json);
void set_member(hive::protocol::public_key_type& member, const JsonbValue& json);
void set_member(int8_t& member, const JsonbValue& json);
void set_member(uint8_t& member, const JsonbValue& json);
void set_member(int16_t& member, const JsonbValue& json);
void set_member(uint16_t& member, const JsonbValue& json);
void set_member(int32_t& member, const JsonbValue& json);
void set_member(uint32_t& member, const JsonbValue& json);
void set_member(int64_t& member, const JsonbValue& json);
void set_member(uint64_t& member, const JsonbValue& json);
template <typename T>
void set_member(fc::safe<T>& member, const JsonbValue& json);
void set_member(hive::protocol::legacy_asset& member, const JsonbValue& json);
void set_member(hive::protocol::legacy_hive_asset& member, const JsonbValue& json);
void set_member(hive::protocol::asset& member, const JsonbValue& json);
void set_member(fc::time_point_sec& member, const JsonbValue& json);
void set_member(fc::sha256& member, const JsonbValue& json);
void set_member(fc::ripemd160& member, const JsonbValue& json);
template<typename T, size_t N>
void set_member(fc::array<T, N>& member, const JsonbValue& json);
void set_member(bool& member, const JsonbValue& json);
template <typename A, typename B>
void set_member(std::pair<A, B>& member, const JsonbValue& json);
template <typename T>
void set_member(fc::optional<T>& member, const JsonbValue& json);
void set_member(std::vector<char>& member, const JsonbValue& json);
template <typename T>
void set_member(std::vector<T>& member, const JsonbValue& json);
template <typename T>
void set_member(boost::container::flat_set<T>& member, const JsonbValue& json);
template <typename T>
void set_member(flat_set_ex<T>& member, const JsonbValue& json);
template <typename K, typename T>
void set_member(boost::container::flat_map<K, T>& member, const JsonbValue& json);
template <typename T>
void set_member(T& member, const JsonbValue& json);
template <typename... Types>
void set_member(fc::static_variant<Types...>& member, const JsonbValue& json);

template <typename T>
void fill_members(T& obj, const JsonbValue& json);

template <typename Storage>
void set_member(hive::protocol::fixed_string_impl<Storage>& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvString);
  member = std::string(json.val.string.val, json.val.string.len);
}
void set_member(hive::protocol::json_string& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvString);
  member = std::string(json.val.string.val, json.val.string.len);
}
void set_member(std::string& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvString);
  member = std::string(json.val.string.val, json.val.string.len);
}
void set_member(hive::protocol::public_key_type& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvString);
  const auto str = std::string(json.val.string.val, json.val.string.len);
  member = hive::protocol::public_key_type(str);
}
void set_member(int8_t& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvNumeric);
  // TODO: error on overflow?
  member = static_cast<int8_t>(DatumGetUInt8(DirectFunctionCall1(numeric_int2, NumericGetDatum(json.val.numeric))));
}
void set_member(uint8_t& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvNumeric);
  member = DatumGetUInt8(DirectFunctionCall1(numeric_int2, NumericGetDatum(json.val.numeric)));
}
void set_member(int16_t& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvNumeric);
  member = DatumGetInt16(DirectFunctionCall1(numeric_int2, NumericGetDatum(json.val.numeric)));
}
void set_member(uint16_t& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvNumeric);
  // TODO: error on overflow?
  member = static_cast<uint16_t>(DatumGetInt16(DirectFunctionCall1(numeric_int4, NumericGetDatum(json.val.numeric))));
}
void set_member(int32_t& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvNumeric);
  member = DatumGetInt32(DirectFunctionCall1(numeric_int4, NumericGetDatum(json.val.numeric)));
}
void set_member(uint32_t& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvNumeric);
  // TODO: error on overflow?
  member = static_cast<uint32_t>(DatumGetInt32(DirectFunctionCall1(numeric_int8, NumericGetDatum(json.val.numeric))));
}
void set_member(int64_t& member, const JsonbValue& json)
{
  if (json.type == jbvNumeric)
  {
    // TODO: error on overflow?
    member = DatumGetInt64(DirectFunctionCall1(numeric_int8, NumericGetDatum(json.val.numeric)));
  }
  else if (json.type == jbvString)
  {
    // TODO: error on overflow?
    const auto str = std::string(json.val.string.val, json.val.string.len);
    Datum num = DirectFunctionCall3(numeric_in, CStringGetDatum(str.c_str()), ObjectIdGetDatum(InvalidOid), Int32GetDatum(-1));
    member = DatumGetInt64(DirectFunctionCall1(numeric_int8, num));
  }
  else
  {
    FC_THROW_EXCEPTION(fc::invalid_arg_exception, "Must be numeric or string type");
  }
}
void set_member(uint64_t& member, const JsonbValue& json)
{
  if (json.type == jbvNumeric)
  {
    // TODO: error on overflow?
    member = static_cast<uint64_t>(DatumGetInt64(DirectFunctionCall1(numeric_int8, NumericGetDatum(json.val.numeric))));
  }
  else if (json.type == jbvString)
  {
    // TODO: error on overflow?
    const auto str = std::string(json.val.string.val, json.val.string.len);
    Datum num = DirectFunctionCall3(numeric_in, CStringGetDatum(str.c_str()), ObjectIdGetDatum(InvalidOid), Int32GetDatum(-1));
    member = static_cast<uint64_t>(DatumGetInt64(DirectFunctionCall1(numeric_int8, num)));
  }
  else
  {
    FC_THROW_EXCEPTION(fc::invalid_arg_exception, "Must be numeric or string type");
  }
}
template <typename T>
void set_member(fc::safe<T>& member, const JsonbValue& json)
{
  T tmp;
  set_member(tmp, json);
  member.value = tmp;
}
void set_member(hive::protocol::legacy_asset& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvString);
  const auto str = std::string(json.val.string.val, json.val.string.len);
  member = hive::protocol::legacy_asset::from_string(str);
}
void set_member(hive::protocol::legacy_hive_asset& member, const JsonbValue& json)
{
  hive::protocol::asset a;
  set_member(a, json);
  member = hive::protocol::legacy_hive_asset::from_asset(a);
}
void set_member(hive::protocol::asset& member, const JsonbValue& json)
{
  if(hive::protocol::serialization_mode_controller::legacy_enabled())
  {
    hive::protocol::legacy_asset a;
    set_member(a, json);
    member = a.to_asset();
  }
  else
  {
    FC_ASSERT(json.type == jbvBinary);
    FC_ASSERT(JsonContainerIsObject(json.val.binary.data));
    JsonbValue amount {};
    JsonbValue precision {};
    JsonbValue nai {};
    getKeyJsonValueFromContainer(json.val.binary.data, "amount", 6, &amount);
    getKeyJsonValueFromContainer(json.val.binary.data, "precision", 9, &precision);
    getKeyJsonValueFromContainer(json.val.binary.data, "nai", 3, &nai);
    FC_ASSERT(amount.type == jbvString);
    FC_ASSERT(precision.type == jbvNumeric);
    FC_ASSERT(nai.type == jbvString);
    const auto amountStr = std::string(amount.val.string.val, amount.val.string.len);
    const auto naiStr = std::string(nai.val.string.val, nai.val.string.len);
    uint8_t precisionInt;
    set_member(precisionInt, precision);
    const auto amountInt = boost::lexical_cast<int64_t>(amountStr);
    FC_ASSERT(amountInt >= 0, "Asset amount cannot be negative");
    member.amount = amountInt;
    member.symbol = hive::protocol::asset_symbol_type::from_nai_string(naiStr.c_str(), precisionInt);
  }
}
void set_member(fc::time_point_sec& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvString);
  const auto str = std::string(json.val.string.val, json.val.string.len);
  member = fc::time_point_sec::from_iso_string(str);
}
void set_member(fc::sha256& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvString);
  if (json.val.string.len > 0)
  {
    std::vector<char> data;
    set_member(data, json);
    memcpy(&member, data.data(), fc::min<size_t>(data.size(), sizeof(member)));
  }
  else
  {
    member = {};
  }
}
void set_member(fc::ripemd160& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvString);
  if (json.val.string.len > 0)
  {
    std::vector<char> data;
    set_member(data, json);
    memcpy(&member, data.data(), fc::min<size_t>(data.size(), sizeof(member)));
  }
  else
  {
    member = {};
  }
}
template<typename T, size_t N>
void set_member(fc::array<T, N>& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvString);
  if (json.val.string.len > 0)
  {
    std::vector<char> data;
    set_member(data, json);
    memcpy(&member, data.data(), fc::min<size_t>(data.size(), sizeof(member)));
  }
  else
  {
    member = {};
  }
}
void set_member(bool& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvBool);
  member = json.val.boolean;
}
template <typename A, typename B>
void set_member(std::pair<A, B>& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvBinary);
  FC_ASSERT(JsonContainerIsArray(json.val.binary.data));
  const auto elementCount = JsonContainerSize(json.val.binary.data);
  FC_ASSERT(elementCount == 2);
  A a{};
  B b{};
  set_member(a, *getIthJsonbValueFromContainer(json.val.binary.data, 0));
  set_member(b, *getIthJsonbValueFromContainer(json.val.binary.data, 1));
  member = std::pair(a, b);
}
template <typename T>
void set_member(fc::optional<T>& member, const JsonbValue& json)
{
  if (json.type == jbvNull)
  {
    member = {};
  }
  else
  {
    T tmp{};
    set_member(tmp, json);
    member = tmp;
  }
}
void set_member(std::vector<char>& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvString);
  const auto buflen = json.val.string.len / 2;
  member.resize(buflen, 0);
  const fc::string str = std::string(json.val.string.val, json.val.string.len);
  fc::from_hex(str, member.data(), buflen);
}
template <typename T>
void set_member(std::vector<T>& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvBinary);
  FC_ASSERT(JsonContainerIsArray(json.val.binary.data));
  const auto elementCount = JsonContainerSize(json.val.binary.data);
  member.resize(elementCount);
  for (uint32 n = 0; n < elementCount; ++n)
  {
    set_member(member[n], *getIthJsonbValueFromContainer(json.val.binary.data, n));
  }
}
template <typename T>
void set_member(boost::container::flat_set<T>& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvBinary);
  FC_ASSERT(JsonContainerIsArray(json.val.binary.data));
  const auto elementCount = JsonContainerSize(json.val.binary.data);
  member.reserve(elementCount);
  for (uint32 n = 0; n < elementCount; ++n)
  {
    T t {};
    set_member(t, *getIthJsonbValueFromContainer(json.val.binary.data, n));
    member.insert(std::move(t));
  }
}
template <typename T>
void set_member(flat_set_ex<T>& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvBinary);
  FC_ASSERT(JsonContainerIsArray(json.val.binary.data));
  const auto elementCount = JsonContainerSize(json.val.binary.data);
  member.reserve(elementCount);
  for (uint32 n = 0; n < elementCount; ++n)
  {
    T tmp {};
    set_member(tmp, *getIthJsonbValueFromContainer(json.val.binary.data, n));
    if (!member.empty())
    {
      FC_ASSERT(tmp > *member.rbegin(), "Items should be unique and sorted");
    }
    member.insert(std::move(tmp));
  }
}
template<typename K, typename T>
void set_member(boost::container::flat_map<K, T>& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvBinary);
  FC_ASSERT(JsonContainerIsArray(json.val.binary.data));
  const auto elementCount = JsonContainerSize(json.val.binary.data);
  member.reserve(elementCount);
  for (uint32 n = 0; n < elementCount; ++n)
  {
    std::pair<K, T> tmp {};
    set_member(tmp, *getIthJsonbValueFromContainer(json.val.binary.data, n));
    member.insert(std::move(tmp));
  }
}
template <typename T>
void set_member(T& member, const JsonbValue& json)
{
  ereport( NOTICE, ( errmsg( "%s", fc::get_typename<T>::name() ) ) );
  static_assert(fc::reflector<T>::is_defined::value);
  FC_ASSERT(json.type == jbvBinary);
  FC_ASSERT(JsonContainerIsObject(json.val.binary.data));
  fill_members(member, json);
}

template<typename T>
class member_from_jsonb_visitor
{
  public:
    member_from_jsonb_visitor(T* op, const JsonbValue& jsonb) :
      op(op), jsonb(jsonb)
    {
      FC_ASSERT(jsonb.type == jbvBinary);
      FC_ASSERT(JsonContainerIsObject(jsonb.val.binary.data));
    }

    template<typename Member, class Class, Member (Class::*member)>
    void operator()(const char* name) const
    {
      JsonbValue value {};
      if (getKeyJsonValueFromContainer(jsonb.val.binary.data, name, strlen(name), &value))
      {
        set_member(op->*member, value);
      }
    }

  private:
    T* op;
    const JsonbValue& jsonb;
};

class static_variant_from_jsonb_visitor
{
  public:
    using result_type = void;

    static_variant_from_jsonb_visitor(const JsonbValue& jsonb) : jsonb(jsonb)
    {}

    template<typename T>
    void operator()(T& op) const
    {
      set_member(op, jsonb);
    }

  private:
    const JsonbValue& jsonb;
};

   struct get_static_variant_name
   {
     std::string& name;
      get_static_variant_name( std::string& n )
         : name( n ) {}

      typedef void result_type;

      template< typename T > void operator()( const T& v )const
      {
         name = fc::trim_typename_namespace( fc::get_typename< T >::name() );
      }
   };

template <typename... Types>
void set_member(fc::static_variant<Types...>& member, const JsonbValue& json)
{
  // TODO: copied from fc::from_variant( const fc::variant& v, fc::static_variant<T...>& s )
  static std::map< std::string, int64_t > to_tag = []()
  {
    std::map< std::string, int64_t > name_map;
    for( int i = 0; i < fc::static_variant<Types...>::count(); ++i )
    {
      fc::static_variant<Types...> tmp;
      tmp.set_which(i);
      std::string n;
      tmp.visit(get_static_variant_name(n));
      name_map[n] = i;
    }
    return name_map;
  }();
  FC_ASSERT(json.type == jbvBinary);
  FC_ASSERT(JsonContainerIsObject(json.val.binary.data));
  JsonbValue type {};
  JsonbValue value {};
  getKeyJsonValueFromContainer(json.val.binary.data, "type", 4, &type);
  getKeyJsonValueFromContainer(json.val.binary.data, "value", 5, &value);
  FC_ASSERT(type.type == jbvString);
  FC_ASSERT(value.type == jbvBinary);
  FC_ASSERT(JsonContainerIsObject(value.val.binary.data));
  const auto tag = std::string(type.val.string.val, type.val.string.len);
  const auto itr = to_tag.find(tag);
  FC_ASSERT( itr != to_tag.end(), "Invalid object name: ${n}", ("n", tag) );
  const int64_t which = itr->second;
  member.set_which(which);
  member.visit(static_variant_from_jsonb_visitor(value));
}

template <typename T>
void fill_members(T& obj, const JsonbValue& json)
{
  fc::reflector<T>::visit(member_from_jsonb_visitor(&obj, json));
}

// TODO: rename
hive::protocol::operation operation_from_jsonb_value(Jsonb* jsonb)
{
  try
  {
    hive::protocol::operation op;
    JsonbValue json {};
    JsonbToJsonbValue(jsonb, &json);
    set_member(op, json);
    return op;
  }
  catch( const fc::exception& e )
  {
    ereport( ERROR, ( errcode( ERRCODE_INVALID_TEXT_REPRESENTATION ), errmsg( "%s", e.to_string().c_str() ) ) );
  }
  catch( const std::exception& e )
  {
    ereport( ERROR, ( errcode( ERRCODE_INVALID_TEXT_REPRESENTATION ), errmsg( "%s", e.what() ) ) );
  }
  catch( ... )
  {
    ereport( ERROR, ( errcode( ERRCODE_INVALID_TEXT_REPRESENTATION ), errmsg( "Unexpected error during jsonb to operation conversion occurred" ) ) );
  }
}
