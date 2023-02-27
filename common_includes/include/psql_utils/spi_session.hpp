#pragma once

#include <boost/optional.hpp>

#include <memory>

extern "C" {
struct tupleDesc;
typedef tupleDesc* TupleDesc;
struct HeapTupleData;
typedef HeapTupleData *HeapTuple;
} // extern "C"

namespace PsqlTools::PsqlUtils {
  class SelectResultIterator;

  class ISelectResult {
  public:
    virtual const std::string& getQuery() const= 0;
    virtual TupleDesc getTupleDesc() = 0;
    virtual boost::optional< HeapTuple > next() = 0;
  };

  class SpiSession {
    public:
      ~SpiSession();

      static std::shared_ptr< SpiSession > create();
      // read only queries - SELECT ...
      std::shared_ptr< ISelectResult > executeSelect( std::string _select_query ) const;
      // utils queries like CREATE TABLE
      void executeUtil(const std::string& _query ) const;
    private:
      SpiSession();
  };

} // namespace PsqlTools::PsqlUtilsSpi
