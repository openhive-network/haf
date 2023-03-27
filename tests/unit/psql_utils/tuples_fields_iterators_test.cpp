#include <boost/test/unit_test.hpp>

#include "include/exceptions.hpp"
#include "psql_utils/postgres_includes.hpp"
#include "psql_utils/to_bytea.hpp"
#include "psql_utils/tuple_fields_iterators.hpp"


#include <cstring>
#include <memory>

#pragma pack( push, 1)
struct TupleExample {
    uint16_t m_number_of_fields = 1280;//htons( (uint16_t)5 );

    uint32_t m_field1_size = htonl( sizeof( uint32_t ) );
    uint32_t m_field1_value = 0xABCDEFAB;

    uint32_t m_field2_size = htonl( sizeof( float ) );
    float m_field2_value = 123.456;

    uint32_t m_field3_size = htonl( 5 );
    char m_field3_value[ 5 ] = "abcd";

    uint32_t m_field4_size = htonl( -1 );

    uint32_t m_field5_size = htonl( sizeof( uint8_t ) );
    uint8_t m_field5_value = 'S';
};
#pragma pack( pop )

BOOST_AUTO_TEST_SUITE( tuples_fileds_iterators )

BOOST_AUTO_TEST_CASE( simple_iteration_by_fields )
{
  TupleExample tuple_pattern;
  auto tuple_bytea = PsqlTools::PsqlUtils::toBytea( &tuple_pattern );

  PsqlTools::PsqlUtils::TuplesFieldIterator it_under_test( tuple_bytea.get() );

  auto field1 = it_under_test.next();
  BOOST_REQUIRE( field1 );
  BOOST_REQUIRE_EQUAL( (*field1).getSize(), ntohl( tuple_pattern.m_field1_size ) );
  BOOST_REQUIRE_EQUAL( *reinterpret_cast< uint32_t* >( (*field1).getValue() ), tuple_pattern.m_field1_value );

  auto field2 = it_under_test.next();
  BOOST_REQUIRE( field2 );
  BOOST_REQUIRE_EQUAL( (*field2).getSize(), ntohl( tuple_pattern.m_field2_size ) );
  BOOST_REQUIRE_EQUAL( *reinterpret_cast< float* >( (*field2).getValue() ), tuple_pattern.m_field2_value );

  auto field3 = it_under_test.next();
  BOOST_REQUIRE( field3 );
  BOOST_REQUIRE_EQUAL( (*field3).getSize(), ntohl( tuple_pattern.m_field3_size ) );
  BOOST_REQUIRE_EQUAL( reinterpret_cast< char* >( (*field3).getValue() ), tuple_pattern.m_field3_value );

  auto field4 = it_under_test.next();
  BOOST_REQUIRE( field4 );
  BOOST_REQUIRE( (*field4).isNullValue() );
  BOOST_REQUIRE_EQUAL( (*field3).getSize(), ntohl( tuple_pattern.m_field3_size ) );

  auto field5 = it_under_test.next();
  BOOST_REQUIRE( field5 );
  BOOST_REQUIRE( !(*field5).isNullValue() );
  BOOST_REQUIRE_EQUAL( (*field5).getSize(), ntohl( tuple_pattern.m_field5_size ) );
  BOOST_REQUIRE_EQUAL( *(*field5).getValue(), tuple_pattern.m_field5_value );

  BOOST_REQUIRE( !it_under_test.next() );
}

BOOST_AUTO_TEST_CASE( negative_incorrect_tuple_format ) {
  TupleExample tuple_pattern;
  tuple_pattern.m_number_of_fields = htons( 20 ); // number of fields is greater than available memory

  auto tuple_bytea = PsqlTools::PsqlUtils::toBytea( &tuple_pattern );
  PsqlTools::PsqlUtils::TuplesFieldIterator it_under_test( tuple_bytea.get() );

  it_under_test.next();
  it_under_test.next();
  it_under_test.next();
  it_under_test.next();
  it_under_test.next();

  // Now try to iterate to 6th field which does not exists
  BOOST_CHECK_THROW( it_under_test.next(), std::runtime_error );
}

BOOST_AUTO_TEST_CASE( empty_tuple ) {
  TupleExample tuple_pattern;
  tuple_pattern.m_number_of_fields = 0;

  auto tuple_bytea = PsqlTools::PsqlUtils::toBytea( &tuple_pattern );
  PsqlTools::PsqlUtils::TuplesFieldIterator it_under_test( tuple_bytea.get() );

  BOOST_REQUIRE( !it_under_test.next() );
}

BOOST_AUTO_TEST_CASE( negative_nullptr_as_param ) {

  BOOST_CHECK_THROW(
      PsqlTools::PsqlUtils::TuplesFieldIterator it_under_test( nullptr )
    , PsqlTools::ObjectInitializationException

  );
}

BOOST_AUTO_TEST_SUITE_END()
