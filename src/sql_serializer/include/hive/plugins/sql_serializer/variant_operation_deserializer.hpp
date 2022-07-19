#pragma once

#include <hive/plugins/sql_serializer/data_2_sql_tuple_base.h>

#include <hive/protocol/operations.hpp>

namespace hive::plugins::sql_serializer {

  namespace hp = hive::protocol;

  class variant_type_parser;

  template< typename T >
  class deserializer
  {
    static variant_type_parser parser;

    const std::string prefix;
    const std::string suffix;

    // This must be modifiable
    mutable std::string result;
    mutable int members_applied = 0;

  public:
    deserializer( const std::string& prefix, const std::string& suffix )
      : prefix( prefix ), suffix( suffix ), result( prefix ) {}

    template< typename SubType >
    void operator()( const SubType& parse )const // This must be const due to the reflect implementation
    {
      result += parser( parse );

      if( ++members_applied < fc::reflector<T>::total_member_count )
        result += ',';
    }

    std::string get_result( const std::string& type )const
    {
      return result + suffix + "::hive." + type;
    }

    std::string get_result()const
    {
      return get_result( fc::get_typename<T>::name() );
    }
  };

  class variant_type_parser : public data2_sql_tuple_base
  {
  public:
    using data2_sql_tuple_base::data2_sql_tuple_base;

    using result_type = std::string;

    result_type operator()( const hp::account_name_type& type )const;
    result_type operator()( const hp::public_key_type& type )const;
    result_type operator()( const std::string& type )const;
    result_type operator()( const hp::json_string& type )const;
    result_type operator()( const fc::time_point_sec& type )const;
    result_type operator()( const fc::sha256& type )const;

    result_type operator()( bool type )const;
    result_type operator()( int8_t type )const;
    result_type operator()( uint8_t type )const;
    result_type operator()( int16_t type )const;
    result_type operator()( uint16_t type )const;
    result_type operator()( int32_t type )const;
    result_type operator()( uint32_t type )const;
    result_type operator()( int64_t type )const;
    result_type operator()( uint64_t type )const;
    result_type operator()( hp::curve_id type )const;
    result_type operator()( const fc::uint128_t& type )const;

    template< typename T >
    result_type operator()( const hp::fixed_string_impl< T >& type )const
    {
      return this->operator()( type.data );
    }

    template< typename T >
    result_type operator()( const std::vector< T >& type )const
    {
      deserializer<T> _deserializer{ "ARRAY[", "]" };

      for( const auto& data : type )
        _deserializer( data );

      return _deserializer.get_result();
    }

    result_type operator()( const std::vector< char >& type )const;

    template< typename K, typename V >
    result_type operator()( const std::pair< K, V >& type )const
    {
      return "ROW(" + this->operator()( type.first ) + "," + this->operator()( type.second ) + ")";
    }

    template< typename K, typename V >
    result_type operator()( const boost::container::flat_map< K, V >& type )const
    {
      std::string str_res = "ARRAY[";
      for( const auto& data : type )
        str_res += this->operator()( data );
      return str_res + "]";
    }

    template< typename T >
    result_type operator()( const boost::container::flat_set<T>& type )const
    {
      deserializer<T> _deserializer{ "ARRAY[", "]" };

      for( const auto& data : type )
        _deserializer( data );

      return _deserializer.get_result();
    }

    template< typename... Ts >
    result_type operator()( const fc::static_variant< Ts... >& type )const;

    template< typename T >
    result_type operator()( const fc::optional< T >& type )const
    {
      if( type.valid() )
        return this->operator()( type.value() );
      else
        return "NULL";
    }

    template< typename T >
    result_type operator()( const fc::safe< T >& type )const
    {
      return this->operator()( type.value );
    }

    template< typename T >
    result_type operator()( const T& type )const;
  };

  class variant_operation_deserializer
  {
  private:
    template< typename op_type >
    class operation_deserializer_visitor
    {
    private:
      deserializer< op_type > _deserializer;

      const op_type& op;

    public:
      operation_deserializer_visitor( const op_type& op )
        : _deserializer( "ROW(", ")" ), op( op ) {}

      template< typename member_type, typename type, member_type(type::*pointer_to_type_member) >
      void operator()( [[maybe_unused]] const char* member_name )const // This must be const due to the reflect implementation
      {
        _deserializer( op.*pointer_to_type_member );
      }

      std::string get_result()const
      {
        return _deserializer.get_result();
      }
    };

  public:
    using result_type = std::string;

    template< typename T >
    result_type operator()( const T& op )const
    {
      operation_deserializer_visitor<T> odv{ op };

      static_assert( fc::reflector<T>::is_defined::value, "Type should be reflected before using it in deserialization" );

      fc::reflector<T>::visit( odv );

      return odv.get_result();
    }
  };

  template< typename... Ts >
  variant_type_parser::result_type variant_type_parser::operator()( const fc::static_variant< Ts... >& type )const
  {
    return type.visit( variant_operation_deserializer{} );
  }

  template< typename T >
  variant_type_parser::result_type variant_type_parser::operator()( const T& type )const
  {
    return variant_operation_deserializer{}.operator()( type );
  }

}
