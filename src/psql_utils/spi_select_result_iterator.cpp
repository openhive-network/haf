#include "spi_select_result_iterator.hpp"

#include "include/exceptions.hpp"

#include "psql_utils/postgres_includes.hpp"

#include <cassert>

using namespace std::string_literals;

namespace {
  std::weak_ptr< PsqlTools::PsqlUtils::SelectResultIterator > ITERATOR_INSTANCE;
}

namespace PsqlTools::PsqlUtils {

SelectResultIterator::~SelectResultIterator() {
  SPI_freetuptable( SPI_tuptable );
}

std::shared_ptr<SelectResultIterator>
SelectResultIterator::create( std::shared_ptr< SpiSession > _session, std::string _query ) {
  auto previous_result_it = ITERATOR_INSTANCE.lock();
  if ( ITERATOR_INSTANCE.lock() ) {
    THROW_RUNTIME_ERROR( "Cannot execute two queries with SPI. Result of query "s + previous_result_it->getQuery() + " is still in use"s );
  }

  std::shared_ptr< SelectResultIterator > new_iterator(new SelectResultIterator( _session, std::move(_query ) ) );
  ITERATOR_INSTANCE = new_iterator;
  return new_iterator;
}

SelectResultIterator::SelectResultIterator(std::shared_ptr< SpiSession > _session, std::string _query ): m_query(std::move(_query ) )  {
  if ( _session == nullptr ) {
    THROW_INITIALIZATION_ERROR( "No SpiSession in progress" );
  }

  constexpr auto all_rows = 0L;
  auto result = SPI_execute( m_query.c_str(), true, all_rows );
  if ( result != SPI_OK_SELECT ) {
    THROW_INITIALIZATION_ERROR( "Cannot execute query "s + m_query );
  }
}

const std::string&
SelectResultIterator::getQuery() const {
  return m_query;
}

TupleDesc
SelectResultIterator::getTupleDesc() {
  return SPI_tuptable->tupdesc;
}

boost::optional< HeapTuple >
SelectResultIterator::next() {
  if ( m_current_row_id >= SPI_processed ) {
    return boost::optional< HeapTuple >();
  }

  return boost::optional< HeapTuple >( *(SPI_tuptable->vals + m_current_row_id++) );
}

} // namespace PsqlTools::PsqlUtils

