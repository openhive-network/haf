#include "include/psql_utils/tuples_iterator.hpp"

#include "include/exceptions.hpp"
#include "include/psql_utils/postgres_includes.hpp"

#include <cassert>

namespace PsqlTools::PsqlUtils {

TuplesStoreIterator::TuplesStoreIterator( Tuplestorestate* _tuples ) : m_tuples( _tuples ) {
  m_slot = MakeTupleTableSlot();
  if ( !m_slot ) {
    THROW_INITIALIZATION_ERROR( "Cannot create tuples slot" );
  }
  tuplestore_rescan( m_tuples );
}


boost::optional< HeapTupleData& >
TuplesStoreIterator::next() {
  if ( !tuplestore_gettupleslot( m_tuples, true, false, m_slot ) )
    return boost::optional< HeapTupleData& >();

  return boost::optional< HeapTupleData& >( *m_slot->tts_tuple );
}
} // namespace PsqlTools::PsqlUtils
