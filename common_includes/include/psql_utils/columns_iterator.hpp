#pragma once

#include <boost/optional.hpp>

#include <functional>

extern "C" {
  struct tupleDesc;
}

namespace PsqlTools::PsqlUtils {
    
  class ColumnsIterator {
  public:
    ColumnsIterator( const tupleDesc& _desc ); // lifetime of _desc controlled by the postgres
    ~ColumnsIterator() = default;

    boost::optional<std::string> next();

  private:
    std::reference_wrapper< const tupleDesc > m_tuple_desc;
    uint16_t m_current_column;
  };
} // namespace PsqlTools::PsqlUtils
