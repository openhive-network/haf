#pragma once

#include <hive/plugins/sql_serializer/data_2_sql_tuple_base.h>

#include <hive/protocol/operations.hpp>

namespace hive::plugins::sql_serializer {

  namespace hp = hive::protocol;

  class variant_type_parser : public data2_sql_tuple_base
  {
  public:
    using data2_sql_tuple_base::data2_sql_tuple_base;

    using result_type = std::string;

    result_type operator()( const hp::asset& type )const;
    result_type operator()( const hp::price& type )const;
    result_type operator()( const hp::account_name_type& type )const;
    result_type operator()( const hp::public_key_type& type )const;
    result_type operator()( const std::string& type )const;
    result_type operator()( const hp::authority& type )const;
    result_type operator()( const fc::time_point_sec& type )const;

    result_type operator()( bool type )const;
    result_type operator()( int8_t type )const;
    result_type operator()( uint8_t type )const;
    result_type operator()( int16_t type )const;
    result_type operator()( uint16_t type )const;
    result_type operator()( int32_t type )const;
    result_type operator()( uint32_t type )const;
    result_type operator()( int64_t type )const;
    result_type operator()( uint64_t type )const;
    result_type operator()( fc::uint128_t type )const;

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
  };

  class variant_operation_deserializer
  {
  private:
    template< typename op_type >
    class operation_deserializer_visitor
    {
    private:
      static variant_type_parser parser;

      // This must be modifiable
      mutable std::string result = "ROW";
      mutable int members_applied = 0;

      const op_type& op;

    public:
      operation_deserializer_visitor( const op_type& op ) : op( op ) {}

      template< typename member_type, typename type, typename member_type(type::*pointer_to_type_member) >
      void operator()( [[maybe_unused]] const char* member_name )const // This must be const due to the reflect implementation
      {
        static_assert( std::is_same< op_type, type >::value, "Operation type and reflected type are not the same" );

        result += parser( op.*pointer_to_type_member );

        if( ++members_applied < fc::reflector<type>::total_member_count )
          result += ',';
      }

      std::string get_result()const
      {
        return result + ")::hive." + fc::get_typename<op_type>::name();
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

}
