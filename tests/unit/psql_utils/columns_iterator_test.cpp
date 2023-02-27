#include <boost/test/unit_test.hpp>

#include "include/psql_utils/columns_iterator.hpp"

#include "mock/postgres_mock.hpp"

#include <cstring>

BOOST_AUTO_TEST_SUITE( columns_iterator )

BOOST_AUTO_TEST_CASE( positive_iteration_threw_columns ) {
  tupleDesc desc;
  desc.natts = 4;
  FormData_pg_attribute attr0 = {};std::strcpy( attr0.attname.data, "COLUMN_1" );
  FormData_pg_attribute attr1 = {};std::strcpy( attr1.attname.data, "COLUMN_2" );
  FormData_pg_attribute attr2 = {};std::strcpy( attr2.attname.data, "COLUMN_3" );
  FormData_pg_attribute attr3 = {};std::strcpy( attr3.attname.data, "COLUMN_4" );
  FormData_pg_attribute* columns_attributes[] = { &attr0, &attr1, &attr2, &attr3 };
  desc.attrs = columns_attributes;

  PsqlTools::PsqlUtils::ColumnsIterator iterator_under_test( desc );

  BOOST_REQUIRE_EQUAL( *iterator_under_test.next(), "COLUMN_1" );
  BOOST_REQUIRE_EQUAL( *iterator_under_test.next(), "COLUMN_2" );
  BOOST_REQUIRE_EQUAL( *iterator_under_test.next(), "COLUMN_3" );
  BOOST_REQUIRE_EQUAL( *iterator_under_test.next(), "COLUMN_4" );

  BOOST_REQUIRE( !iterator_under_test.next() );
}

BOOST_AUTO_TEST_CASE( no_columns ) {
  tupleDesc desc;
  desc.natts = 0;

  PsqlTools::PsqlUtils::ColumnsIterator iterator_under_test( desc );

  BOOST_REQUIRE( !iterator_under_test.next() );
}

BOOST_AUTO_TEST_SUITE_END()
