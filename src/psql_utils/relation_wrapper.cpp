#include "relation_wrapper.hpp"

#include "include/exceptions.hpp"
#include "psql_utils/postgres_includes.hpp"
#include "psql_utils/tuple_fields_iterators.hpp"

#include <cassert>


using namespace std::string_literals;

namespace PsqlTools::PsqlUtils {
RelationWrapper::RelationWrapper(RelationData* _relation )
  : m_relation( _relation ) {

  if ( m_relation == nullptr ) {
    THROW_INITIALIZATION_ERROR( "Relation is a Null pointer" );
  }
}

std::string binaryValueToText(uint8_t* _value, uint32_t _size, const TupleDesc& _tuple_desc, uint16_t _column_id ) {
  Oid binary_in_func_id;
  Oid params_id;
  Form_pg_attribute attr = TupleDescAttr(_tuple_desc, _column_id );
  getTypeBinaryInputInfo( attr->atttypid, &binary_in_func_id, &params_id );
  FmgrInfo function;
  fmgr_info( binary_in_func_id, &function );

  StringInfo buffer = makeStringInfo();
  appendBinaryStringInfo( buffer, reinterpret_cast<char*>(_value), _size );

  // Here we back from binary value to value
  Datum value = ReceiveFunctionCall(&function, buffer, params_id, attr->atttypmod);

  // Now is time to get string value
  Oid out_function_id;
  bool is_varlen( false );
  getTypeOutputInfo( attr->atttypid, &out_function_id, &is_varlen );
  char* output_bytes = OidOutputFunctionCall( out_function_id, value );

  if ( output_bytes == nullptr ) {
    THROW_RUNTIME_ERROR("Null values in PKey columns is not supported");
  }

  return output_bytes;
}


RelationWrapper::PrimaryKeyColumns
RelationWrapper::getPrimaryKeysColumns() const {
  PrimaryKeyColumns result;

  Oid pkey_oid;
  auto columns_bitmap = get_primary_key_attnos( m_relation->rd_id, true, &pkey_oid );

  if ( columns_bitmap == nullptr ) {
    return result;
  }

  int32_t column = -1;
  while( (column = bms_next_member( columns_bitmap, column ) ) >= 0 ) {
    result.push_back( column + FirstLowInvalidHeapAttributeNumber );
  }
  return result;
}

ColumnsIterator
RelationWrapper::getColumns() const {
  return ColumnsIterator( *m_relation->rd_att );
}

template< typename _JavaLikeIterator >
auto moveIteratorForward( _JavaLikeIterator& _it, uint32_t _number_of_steps ) {
  decltype( _it.next() ) result;
  for ( auto step = 0u; step < _number_of_steps; ++step )
    result = _it.next();

  return result;
}

std::string
RelationWrapper::createPkeyCondition(bytea* _relation_tuple_in_copy_format ) const {
  auto sorted_primary_keys_columns = getPrimaryKeysColumns();
  auto columns_it = getColumns();
  TuplesFieldIterator tuples_fields_it(_relation_tuple_in_copy_format );

  std::string result;
  uint32_t previous_column = 0;
  for ( auto pkey_column_id : sorted_primary_keys_columns ) {
    assert( previous_column <= pkey_column_id && "Pkey columns must be sorted" );

    auto column_name_value = moveIteratorForward( columns_it, pkey_column_id - previous_column );
    assert( column_name_value && "Incosistency between primary keys columns and list of columns" );

    auto field_value = moveIteratorForward( tuples_fields_it, pkey_column_id - previous_column );
    if ( !field_value ) {
      auto message = "Incorrect tuple format table:"s + getName();
      THROW_RUNTIME_ERROR(  message );
    }

    auto value = binaryValueToText( (*field_value).getValue(), (*field_value).getSize(), m_relation->rd_att,
                                   pkey_column_id - 1);
    if ( !result.empty() ) {
      result.append( " AND " );
    }
    result.append( *column_name_value + "="s + value );

    previous_column = pkey_column_id;
  }

  return result;
}

std::string
RelationWrapper::createRowValuesAssignment([[maybe_unused]] bytea* _relation_tuple_in_copy_format ) const {
  assert( m_relation );

  std::string result;
  auto columns_it = getColumns();
  TuplesFieldIterator tuples_fields_it( _relation_tuple_in_copy_format );

  uint32_t column_id = 0;
  while ( auto field_value = tuples_fields_it.next() ) {
    auto column_name = columns_it.next();

    if ( !column_name ) {
      auto message = "Incorrect tuple format table:"s + getName();
      THROW_RUNTIME_ERROR( message );
    }

    auto value = binaryValueToText((*field_value).getValue(), (*field_value).getSize(), m_relation->rd_att, column_id);

    if ( !result.empty() ) {
      result.push_back( ',' );
    }

    auto type_name = SPI_gettype( m_relation->rd_att, column_id + 1 );
    if ( type_name == nullptr ) {
      auto message = "Cannot find a type name for column "s + std::to_string( column_id ) + " of table " + getName();
      THROW_RUNTIME_ERROR( message );
    }

    result.append( *column_name + "='"s + value + "'::" + type_name );
    ++column_id;
  }
  return result;
}


std::string
RelationWrapper::getName() const {
  return SPI_getrelname(m_relation);
}


} // namespace PsqlTools::PsqlUtils
