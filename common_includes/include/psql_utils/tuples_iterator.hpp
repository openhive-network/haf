#pragma once

#include <boost/optional.hpp>

extern "C" {
  typedef struct Tuplestorestate Tuplestorestate;
  struct HeapTupleData;
  struct TupleTableSlot;
}

namespace PsqlTools::PsqlUtils {

  class TuplesStoreIterator {
  public:
      explicit TuplesStoreIterator( Tuplestorestate* _tuples );
      ~TuplesStoreIterator() = default;
      TuplesStoreIterator( const TuplesStoreIterator& ) = delete;
      TuplesStoreIterator& operator=( const TuplesStoreIterator& ) = delete;

      boost::optional< HeapTupleData& > next();

  private:
      Tuplestorestate* m_tuples;
      TupleTableSlot* m_slot;
  };

} // namespace PsqlTools::PsqlUtils

