#include <psql_utils/postgres_includes.hpp>

#include <hive/protocol/operations.hpp>

#include <map>
#include <string>

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
  FC_ASSERT(json.type == jbvNumeric);
  member = DatumGetInt64(DirectFunctionCall1(numeric_int8, NumericGetDatum(json.val.numeric)));
}
void set_member(uint64_t& member, const JsonbValue& json)
{
  FC_ASSERT(json.type == jbvNumeric);
  // TODO: error on overflow?
  member = static_cast<uint64_t>(DatumGetInt64(DirectFunctionCall1(numeric_int8, NumericGetDatum(json.val.numeric))));
}
template <typename T>
void set_member(T& member, const JsonbValue& json)
{
  ereport( NOTICE, ( errmsg( "%s", fc::get_typename<T>::name() ) ) );
}

template<typename T>
class member_from_jsonb_visitor
{
  public:
    member_from_jsonb_visitor(T* op, const JsonbValue& jsonb) :
      op(op), jsonb(jsonb)
    {}

    template<typename Member, class Class, Member (Class::*member)>
    void operator()(const char* name) const
    {
      JsonbValue value {};
      FC_ASSERT(jsonb.type == jbvBinary);
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

    static_variant_from_jsonb_visitor(hive::protocol::operation* op, const JsonbValue& jsonb) : op(op), jsonb(jsonb)
    {}

    template<typename T>
    void operator()(T& op) const
    {
      fc::reflector<T>::visit(member_from_jsonb_visitor(&op, jsonb));
    }

  private:
    hive::protocol::operation* op;
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

// TODO: rename
hive::protocol::operation operation_from_jsonb_value(Jsonb* jsonb)
{
  try
  {
    // TODO: copied from fc::from_variant( const fc::variant& v, fc::static_variant<T...>& s )
    static std::map< std::string, int64_t > to_tag = []()
    {
      std::map< std::string, int64_t > name_map;
      for( int i = 0; i < hive::protocol::operation::count(); ++i )
      {
        hive::protocol::operation tmp;
        tmp.set_which(i);
        std::string n;
        tmp.visit( get_static_variant_name( n ) );
        name_map[n] = i;
      }
      return name_map;
    }();
    hive::protocol::operation op;
    JsonbValue type {};
    JsonbValue value {};
    getKeyJsonValueFromContainer(&jsonb->root, "type", 4, &type);
    getKeyJsonValueFromContainer(&jsonb->root, "value", 5, &value);
    FC_ASSERT(type.type == jbvString);
    FC_ASSERT(value.type == jbvBinary);
    auto tag = std::string(type.val.string.val, type.val.string.len);
    auto itr = to_tag.find(tag);
    FC_ASSERT( itr != to_tag.end(), "Invalid object name: ${n}", ("n", tag) );
    const int64_t which = itr->second;
    op.set_which(which);
    op.visit(static_variant_from_jsonb_visitor(&op, value));
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
