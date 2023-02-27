#include "include/psql_utils/columns_iterator.hpp"

#include "include/psql_utils/postgres_includes.hpp"

namespace PsqlTools::PsqlUtils {

ColumnsIterator::ColumnsIterator( const TupleDescData& _desc )
  : m_tuple_desc( _desc )
  , m_current_column( 0 )
{
}

boost::optional<std::string>
ColumnsIterator::next() {
  if ( m_current_column >= m_tuple_desc.get().natts ) {
    return boost::optional<std::string>();
  }

  auto attribute = TupleDescAttr( &m_tuple_desc.get(), m_current_column );
  ++m_current_column;
  return boost::optional<std::string>( NameStr( attribute->attname ) );
}

} // namespace PsqlTools::PsqlUtils

