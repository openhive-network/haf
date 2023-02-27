#include <boost/test/unit_test.hpp>

#include "include/exceptions.hpp"
#include "include/psql_utils/tuples_iterator.hpp"

#include "mock/postgres_mock.hpp"


BOOST_AUTO_TEST_SUITE( tuples_iterator )

BOOST_AUTO_TEST_CASE( simple_iteration ) {
  auto postgres_mock = PostgresMock::create_and_get();

  Tuplestorestate* tuples_store_ptr = reinterpret_cast< Tuplestorestate* >(0xAABBCCDDEEFFAABB);
  TupleTableSlot tuples_slot;
  HeapTupleData tuple1, tuple2;
  tuples_slot.tts_tuple = &tuple1;
  TupleTableSlot* tuples_slot_ptr = &tuples_slot;

  //1. create slot
  EXPECT_CALL( *postgres_mock, MakeTupleTableSlot() ).Times(1).WillOnce( ::testing::Return( tuples_slot_ptr ) );

  //2. ensure that store will iterate from the beginning
  EXPECT_CALL( *postgres_mock, tuplestore_rescan(tuples_store_ptr) ).Times(1);

  //3. iterations
  EXPECT_CALL(*postgres_mock, tuplestore_gettupleslot( tuples_store_ptr, ::testing::_, ::testing::_, tuples_slot_ptr ) )
    .Times(3)
    .WillOnce( ::testing::Return( true ) )
    .WillOnce( ::testing::InvokeWithoutArgs( [&tuples_slot,&tuple2]{ tuples_slot.tts_tuple = &tuple2; return true; } ) )
    .WillOnce( ::testing::Return( false ) )
  ;

  PsqlTools::PsqlUtils::TuplesStoreIterator iterator_under_test( tuples_store_ptr );

  auto first_it_result = iterator_under_test.next();
  BOOST_REQUIRE( first_it_result );
  BOOST_REQUIRE( &first_it_result.get() == &tuple1 );

  auto second_it_result = iterator_under_test.next();
  BOOST_REQUIRE( second_it_result );
  BOOST_REQUIRE( &second_it_result.get() == &tuple2 );

  auto third_it_result = iterator_under_test.next();
  BOOST_REQUIRE( !third_it_result );
}

BOOST_AUTO_TEST_CASE( no_tuples ){
  auto postgres_mock = PostgresMock::create_and_get();

  Tuplestorestate* tuples_store_ptr = reinterpret_cast< Tuplestorestate* >(0xAABBCCDDEEFFAABB);
  TupleTableSlot tuples_slot;
  TupleTableSlot* tuples_slot_ptr = &tuples_slot;

  //1. create slot
  EXPECT_CALL( *postgres_mock, MakeTupleTableSlot() ).Times(1).WillOnce( ::testing::Return( tuples_slot_ptr ) );

  //2. ensure that store will iterate from the beginning
  EXPECT_CALL( *postgres_mock, tuplestore_rescan(tuples_store_ptr) ).Times(1);

  //3. iterations
  EXPECT_CALL(*postgres_mock, tuplestore_gettupleslot( tuples_store_ptr, ::testing::_, ::testing::_, tuples_slot_ptr ) )
          .Times(1)
          .WillOnce( ::testing::Return( false ) )
  ;

  PsqlTools::PsqlUtils::TuplesStoreIterator iterator_under_test( tuples_store_ptr );

  BOOST_REQUIRE( !iterator_under_test.next() );
}

BOOST_AUTO_TEST_CASE( negative_cannot_create_slot ){
  auto postgres_mock = PostgresMock::create_and_get();

  Tuplestorestate* tuples_store_ptr = reinterpret_cast< Tuplestorestate* >(0xAABBCCDDEEFFAABB);

  EXPECT_CALL( *postgres_mock, MakeTupleTableSlot() ).Times(1).WillOnce( ::testing::Return( nullptr ) );

  BOOST_CHECK_THROW(
      PsqlTools::PsqlUtils::TuplesStoreIterator iterator_under_test( tuples_store_ptr )
    , PsqlTools::ObjectInitializationException
  );
}

BOOST_AUTO_TEST_SUITE_END()