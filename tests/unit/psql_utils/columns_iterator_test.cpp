#include <boost/test/unit_test.hpp>

#include "mock/gmock_fixture.hpp"

#include "psql_utils/columns_iterator.hpp"
#include "catalog/pg_attribute.h"

#include "mock/postgres_mock.hpp"

#include <cstring>

BOOST_FIXTURE_TEST_SUITE( columns_iterator, GmockFixture )

BOOST_AUTO_TEST_CASE( positive_iteration_threw_columns ) {
  auto desc = static_cast<TupleDescData*>(malloc( sizeof(TupleDescData) + 4*(sizeof(FormData_pg_attribute)+sizeof(CompactAttribute)) ));
  desc->natts = 4;

  Form_pg_attribute attr0 = TupleDescAttr(desc, 0);
  *attr0 = {};
  std::strcpy(attr0->attname.data, "COLUMN_1");

  Form_pg_attribute attr1 = TupleDescAttr(desc, 1);
  *attr1 = {};
  std::strcpy(attr1->attname.data, "COLUMN_2");

  Form_pg_attribute attr2 = TupleDescAttr(desc, 2);
  *attr2 = {};
  std::strcpy(attr2->attname.data, "COLUMN_3");

  Form_pg_attribute attr3 = TupleDescAttr(desc, 3);
  *attr3 = {};
  std::strcpy(attr3->attname.data, "COLUMN_4");

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
