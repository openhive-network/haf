#include <psql_utils/postgres_includes.hpp>

#include <hive/protocol/operations.hpp>

#include <map>
#include <string>

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
      op->*member = Member{};
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
  JsonbValue type;
  JsonbValue value;
  getKeyJsonValueFromContainer(&jsonb->root, "type", 4, &type);
  getKeyJsonValueFromContainer(&jsonb->root, "value", 5, &value);
  FC_ASSERT(type.type == jbvString);
  FC_ASSERT(value.type == jbvBinary);
  auto itr = to_tag.find(std::string(type.val.string.val, type.val.string.len));
  FC_ASSERT( itr != to_tag.end(), "Invalid object name: ${n}", ("n", "TODO") );
  const int64_t which = itr->second;
  op.set_which(which);
  op.visit(static_variant_from_jsonb_visitor(&op, value));
  return op;
}
