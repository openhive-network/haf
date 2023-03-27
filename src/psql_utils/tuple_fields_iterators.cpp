#include "psql_utils/tuple_fields_iterators.hpp"

#include "include/exceptions.hpp"

#include <cassert>

namespace PsqlTools::PsqlUtils {

TuplesFieldIterator::TuplesFieldIterator( bytea* _tuple_in_copy_format ) {
  if ( _tuple_in_copy_format == nullptr ) {
    THROW_INITIALIZATION_ERROR( "Null tuple passed" );
  }

  m_tuple_bytes = (uint8_t*)VARDATA_ANY( _tuple_in_copy_format );
  m_tuple_size = VARSIZE_ANY( _tuple_in_copy_format );

  if ( m_tuple_bytes == nullptr ) {
    THROW_INITIALIZATION_ERROR( "Null tuple passed" );
  }

  if ( m_tuple_size < NUMBER_OF_FIELDS_SIZE ) {
    THROW_INITIALIZATION_ERROR( "Size of tuple is to small" );
  }

  m_number_of_fields = ntohs( *reinterpret_cast< uint16_t* >( m_tuple_bytes ) );
  m_current_field_number = 0;
  m_current_field = m_tuple_bytes + NUMBER_OF_FIELDS_SIZE;
}

boost::optional< TuplesFieldIterator::Field >
TuplesFieldIterator::next() {
  if ( atEnd() ) {
    return boost::optional< TuplesFieldIterator::Field >();
  }

  std::size_t column_distant = ( m_current_field - m_tuple_bytes );
  if ( column_distant >= m_tuple_size ) {
    THROW_RUNTIME_ERROR( "Incorrect tuple format: wronkg number of columns" );
  }

  auto result = getField();
  if ( result.isNullValue() ) {
    m_current_field += FIELD_SIZE_SIZE;
  } else {
    m_current_field += FIELD_SIZE_SIZE + result.getSize();
  }
  ++m_current_field_number;

  return result;
}


TuplesFieldIterator::Field
TuplesFieldIterator::getField() const {
  assert( !atEnd() && "Pass-end access");

  uint32_t size = ntohl( *reinterpret_cast< uint32_t* >( m_current_field ) );
  if ( size != 0xFFFFFFFF ) {
    return Field( m_current_field + FIELD_SIZE_SIZE, size );
  }

  return Field( nullptr, size );
}

bool
TuplesFieldIterator::atEnd() const {
  return m_current_field_number == m_number_of_fields;
}

} // namespace PsqlTools::PsqlUtils

