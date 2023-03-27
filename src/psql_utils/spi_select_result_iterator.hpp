#pragma once

#include "psql_utils/spi_session.hpp"

#include <boost/optional.hpp>

#include <memory>
#include <string>

extern "C" {
struct TupleDescData;
typedef TupleDescData* TupleDesc;
struct HeapTupleData;
typedef HeapTupleData *HeapTuple;
} // extern "C"

namespace PsqlTools::PsqlUtils {
  class SpiSession;

  class SelectResultIterator
    : public ISelectResult {
  public:
    ~SelectResultIterator();
    SelectResultIterator(const SelectResultIterator& ) = delete;
    SelectResultIterator(SelectResultIterator&& ) = delete;
    SelectResultIterator& operator=(const SelectResultIterator& ) = delete;
    SelectResultIterator& operator=(SelectResultIterator&& ) = delete;

    static std::shared_ptr<SelectResultIterator> create( std::shared_ptr< SpiSession > _session, std::string _query);

    const std::string& getQuery() const override;
    TupleDesc getTupleDesc() override;
    boost::optional< HeapTuple > next() override;

  private:
    SelectResultIterator( std::shared_ptr< SpiSession > _session, std::string _query );

  private:
    const std::string m_query;
    std::shared_ptr< SpiSession > m_session;
    uint32_t m_current_row_id = 0u;
  };

} // namespace PsqlTools::PsqlUtils
