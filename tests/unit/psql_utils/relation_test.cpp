#include <boost/test/unit_test.hpp>

#include "include/exceptions.hpp"

#include "relation_from_name.hpp"
#include "relation_wrapper.hpp"

#include "mock/postgres_mock.hpp"

BOOST_AUTO_TEST_SUITE( relation )

BOOST_AUTO_TEST_CASE( wrapper_negativy_create ) {
  BOOST_CHECK_THROW(
      PsqlTools::PsqlUtils::RelationWrapper( nullptr )
    , PsqlTools::ObjectInitializationException
  );
}

BOOST_AUTO_TEST_CASE( wrapper_get_pkey_columns ) {
  auto postgres_mock = PostgresMock::create_and_get();
  RelationData raw_relation;
  raw_relation.rd_id = 123;

  Bitmapset* columns_bitmap = reinterpret_cast< Bitmapset* >(0xAABBCCDDEEFFAABB);
  const PsqlTools::PsqlUtils::RelationWrapper::PrimaryKeyColumns expected_columns = {1, 3, 8 };
  static constexpr auto END_OF_BITMAP = -1;

  EXPECT_CALL( *postgres_mock, get_primary_key_attnos( raw_relation.rd_id, true, ::testing::_ ) )
    .Times( 1 )
    .WillOnce( ::testing::Return( columns_bitmap ) );

  EXPECT_CALL( *postgres_mock, bms_next_member( columns_bitmap, -1 ) ).Times( 1 ).WillOnce( ::testing::Return( expected_columns[ 0 ] - FirstLowInvalidHeapAttributeNumber  ) );
  EXPECT_CALL( *postgres_mock, bms_next_member( columns_bitmap, expected_columns[ 0 ] - FirstLowInvalidHeapAttributeNumber ) ).Times( 1 ).WillOnce( ::testing::Return( expected_columns[1] - FirstLowInvalidHeapAttributeNumber ) );
  EXPECT_CALL( *postgres_mock, bms_next_member( columns_bitmap, expected_columns[ 1 ] - FirstLowInvalidHeapAttributeNumber ) ).Times( 1 ).WillOnce( ::testing::Return( expected_columns[2] - FirstLowInvalidHeapAttributeNumber) );
  EXPECT_CALL( *postgres_mock, bms_next_member( columns_bitmap, expected_columns[ 2 ] - FirstLowInvalidHeapAttributeNumber ) ).Times( 1 ).WillOnce( ::testing::Return( END_OF_BITMAP ) );


  PsqlTools::PsqlUtils::RelationWrapper relation_under_test( &raw_relation );

  auto pk_columns = relation_under_test.getPrimaryKeysColumns();

  BOOST_REQUIRE_EQUAL( pk_columns.size(), 3 );
  BOOST_REQUIRE( pk_columns == expected_columns );
}

BOOST_AUTO_TEST_CASE( wrapper_get_name ) {
  auto postgres_mock = PostgresMock::create_and_get();
  auto expected_table_name = "TEST_TABLE";
  RelationData raw_relation;

  EXPECT_CALL( *postgres_mock, SPI_getrelname( &raw_relation ) )
    .Times(1)
    .WillOnce( ::testing::Return( const_cast<char*>( expected_table_name ) ) )
  ;

  PsqlTools::PsqlUtils::RelationWrapper relation_under_test( &raw_relation );

  auto table_name = relation_under_test.getName();

  BOOST_REQUIRE_EQUAL( table_name, expected_table_name );
}

BOOST_AUTO_TEST_CASE( wrapper_get_pkey_columns_no_pk ) {
  auto postgres_mock = PostgresMock::create_and_get();
  RelationData raw_relation;
  raw_relation.rd_id = 123;

  EXPECT_CALL( *postgres_mock, get_primary_key_attnos( raw_relation.rd_id, true, ::testing::_ ) )
          .Times( 1 )
          .WillOnce( ::testing::Return(  nullptr ) );

  PsqlTools::PsqlUtils::RelationWrapper relation_under_test( &raw_relation );

  auto pk_columns = relation_under_test.getPrimaryKeysColumns();

  BOOST_REQUIRE( pk_columns.empty() );
}

BOOST_AUTO_TEST_CASE( relation_from_name ) {
  auto postgres_mock = PostgresMock::create_and_get();

  static constexpr auto RELATION_NAME = "test_relation";
  Relation postgres_relation_ptr = reinterpret_cast< Relation >(0xAABBCCDDEEFFAABB);
  RangeVar* range_var_ptr = reinterpret_cast< RangeVar* >(0xFFFFFFFFFFFFFFFF);

  // 1. create varRange
  EXPECT_CALL( *postgres_mock, makeRangeVar(NULL, ::testing::StrEq( RELATION_NAME ), -1) )
    .Times( 1 )
    .WillOnce( ::testing::Return( range_var_ptr ) )
  ;
  // 2. find the relation by varRange
  EXPECT_CALL( *postgres_mock, heap_openrv( range_var_ptr, AccessShareLock) )
    .Times( 1 )
    .WillOnce( ::testing::Return( postgres_relation_ptr ) )
  ;
  // 3. close the relation
  EXPECT_CALL( *postgres_mock, relation_close( postgres_relation_ptr, NoLock) )
          .Times( 1 )
 ;

  BOOST_CHECK_NO_THROW(
    PsqlTools::PsqlUtils::RelationFromName relation_under_test( RELATION_NAME )
  );
}

BOOST_AUTO_TEST_CASE( negative_relation_from_name_cannot_varrange_create ) {
  auto postgres_mock = PostgresMock::create_and_get();

  // 1. cannot create varRange
  EXPECT_CALL( *postgres_mock, makeRangeVar(::testing::_, ::testing::_, ::testing::_) )
    .WillRepeatedly( ::testing::Return( nullptr ) )
  ;

  BOOST_CHECK_THROW(
      PsqlTools::PsqlUtils::RelationFromName relation_under_test( "any relation" )
    , PsqlTools::ObjectInitializationException
  );
}

BOOST_AUTO_TEST_CASE( negative_relation_from_name_cannot_open_relation ) {
    auto postgres_mock = PostgresMock::create_and_get();

    RangeVar* range_var_ptr = reinterpret_cast< RangeVar* >(0xFFFFFFFFFFFFFFFF);

    // 1. create varRange
    EXPECT_CALL( *postgres_mock, makeRangeVar(::testing::_, ::testing::_, ::testing::_) )
            .Times( 1 )
            .WillOnce( ::testing::Return( range_var_ptr ) )
            ;
    // 2. find the relation by varRange
    EXPECT_CALL( *postgres_mock, heap_openrv( range_var_ptr, AccessShareLock) )
            .Times( 1 )
            .WillOnce( ::testing::Return( nullptr ) )
            ;
    // 3. ensure that close wont be called
    EXPECT_CALL( *postgres_mock, relation_close( ::testing::_, ::testing::_) )
      .Times( 0 )
    ;

  BOOST_CHECK_THROW(
      PsqlTools::PsqlUtils::RelationFromName relation_under_test( "any relation" )
    , PsqlTools::ObjectInitializationException
  );
}

BOOST_AUTO_TEST_SUITE_END()
