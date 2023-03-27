#include <boost/test/unit_test.hpp>

#include "psql_utils/columns_iterator.hpp"

#include "mock/postgres_mock.hpp"

#include <cstring>

BOOST_AUTO_TEST_SUITE( columns_iterator )

BOOST_AUTO_TEST_CASE( positive_iteration_threw_columns ) {
  auto desc = static_cast<TupleDescData*>(malloc( sizeof(TupleDescData) + 4*sizeof(FormData_pg_attribute) ));
  desc->natts = 4;
  desc->attrs[0]={};std::strcpy( desc->attrs[0].attname.data, "COLUMN_1" );
  desc->attrs[1]={};std::strcpy( desc->attrs[1].attname.data, "COLUMN_2" );
  desc->attrs[2]={};std::strcpy( desc->attrs[2].attname.data, "COLUMN_3" );
  desc->attrs[3]={};std::strcpy( desc->attrs[3].attname.data, "COLUMN_4" );



  //desc.attrs = columns_attributes;

  PsqlTools::PsqlUtils::ColumnsIterator iterator_under_test( *desc );

  BOOST_REQUIRE_EQUAL( *iterator_under_test.next(), "COLUMN_1" );
  BOOST_REQUIRE_EQUAL( *iterator_under_test.next(), "COLUMN_2" );
  BOOST_REQUIRE_EQUAL( *iterator_under_test.next(), "COLUMN_3" );
  BOOST_REQUIRE_EQUAL( *iterator_under_test.next(), "COLUMN_4" );

  BOOST_REQUIRE( !iterator_under_test.next() );
}

BOOST_AUTO_TEST_CASE( no_columns ) {
  TupleDescData desc;
  desc.natts = 0;

  PsqlTools::PsqlUtils::ColumnsIterator iterator_under_test( desc );

  BOOST_REQUIRE( !iterator_under_test.next() );
}

BOOST_AUTO_TEST_SUITE_END()
