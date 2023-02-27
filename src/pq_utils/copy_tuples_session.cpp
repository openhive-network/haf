#include "include/pq_utils/copy_tuples_session.hpp"

#include "include/exceptions.hpp"
#include "include/psql_utils/postgres_includes.hpp"

#include <cassert>
#include <numeric>
#include <vector>
#include <exception>

static constexpr auto NULL_FIELD_SIZE = sizeof( uint32_t );
static constexpr auto SIZE_OF_NUMBER_OF_COLUMNS = sizeof( uint16_t );
static constexpr auto SIZE_OF_COLUMN_SIZE = sizeof( uint32_t );

struct FieldSizeAndValue{
    // By default the struct contains NULL value description
    uint32_t size = sizeof(uint32_t);
    char* value = nullptr;
};

FieldSizeAndValue get_size_and_value( const HeapTupleData& _tuple, const TupleDesc& _tuple_desc, uint32_t _column ) {
  FieldSizeAndValue result;

  bool is_null = false;
  Datum binary_value = SPI_getbinval( const_cast< HeapTuple >( &_tuple ), _tuple_desc, _column, &is_null );

  if ( SPI_result == SPI_ERROR_NOATTRIBUTE ) {
    THROW_RUNTIME_ERROR( "Cannot get binary value from a tuple column " + std::to_string( _column ) );
  }

  if ( is_null )
    return result;

  Oid binary_out_func_id;
  bool is_var_len = false;
  Form_pg_attribute attr = TupleDescAttr(_tuple_desc, _column - 1 );
  getTypeBinaryOutputInfo( attr->atttypid, &binary_out_func_id, &is_var_len );

  FmgrInfo function;
  fmgr_info( binary_out_func_id, &function );

  auto value = SendFunctionCall(&function, binary_value);
  result.size = VARSIZE_ANY_EXHDR(value);
  result.value = VARDATA_ANY(value);

  return result;
}


namespace PsqlTools::PostgresPQ {
#pragma pack(push, 1)
  struct BinaryFileFormatHeader {
      char header[11] = "PGCOPY\n\377\r\n";
      const uint32_t flags = 0u;
      const uint32_t extension = 0u;
  };
#pragma pack(pop)

  static_assert( sizeof(BinaryFileFormatHeader) == 19 ); // 15 + extension

  CopyTuplesSession::CopyTuplesSession( std::shared_ptr< pg_conn > _connection, const std::string& _table, const std::vector< std::string >& _columns )
  : CopySession( _connection, _table, _columns )
  , m_null_field_size( htonl( -1 ) )
  , m_trailing_mark( htons( -1 ) )
  {
    static_assert( sizeof( char ) == 1 );

    static const BinaryFileFormatHeader header;
    try {
      push_data( &header, sizeof(BinaryFileFormatHeader));
    } catch ( std::exception& _exception ) {
      THROW_INITIALIZATION_ERROR( _exception.what() );
    }
  }

  CopyTuplesSession::~CopyTuplesSession() {
    try {
      push_trailing();
    } catch ( std::exception& _exception ) {
      LOG_ERROR( "Cannot push COPY trailing: %s", _exception.what() );
    }
  }

  void
  CopyTuplesSession::push_tuple( bytea* _encoded_with_copy_tuple ) {
    auto data_len = VARSIZE_ANY_EXHDR( _encoded_with_copy_tuple );
    push_data( VARDATA_ANY(_encoded_with_copy_tuple), data_len );
  }

  void
  CopyTuplesSession::push_tuple_header( const TupleDesc& _tuple_desc ) {
    push_tuple_header( _tuple_desc->natts );
  }

  void
  CopyTuplesSession::push_tuple_header( uint16_t _number_of_fields ) {
    uint16_t number_of_fields = htons( _number_of_fields );
    push_data( &number_of_fields, sizeof( uint16_t ) );
  }

  void
  CopyTuplesSession::push_tuple_as_next_column( const HeapTupleData& _tuple, const TupleDesc& _tuple_desc ) {
    std::vector< FieldSizeAndValue > binary_values;
    binary_values.reserve( _tuple_desc->natts );

    uint32_t tuple_size = SIZE_OF_NUMBER_OF_COLUMNS;
    for ( auto column = 1; column <= _tuple_desc->natts; ++column ) {
      FieldSizeAndValue size_and_value = get_size_and_value( _tuple, _tuple_desc, column );

      if ( size_and_value.value == nullptr ) {
        tuple_size += NULL_FIELD_SIZE;
      } else {
        tuple_size += SIZE_OF_COLUMN_SIZE;
        tuple_size += size_and_value.size;
      }

      binary_values.push_back( size_and_value );
    }

    // [ tuple_size(32b) [ number_of_columns(16b), size_of_column1(32b), data_of_column1(size_of_column1)...] ]
    //0. push binary tuple size
    tuple_size = htonl( tuple_size );
    push_data( &tuple_size, sizeof( uint32_t ) );

    //1. number of columns
    uint16_t number_of_fields = htons( binary_values.size() );
    push_data( &number_of_fields, sizeof(uint16_t) );

    //2. push each field ( value of columns )
    for ( auto field_value_and_size : binary_values ) {
      if ( field_value_and_size.value == nullptr ) {
        push_null_field();
        continue;
      }

      //2a push size of field
      uint32_t len = htonl( field_value_and_size.size );
      push_data( &len, sizeof(uint32_t) );
      //2b push field's data
      push_data( field_value_and_size.value, field_value_and_size.size );
    }
  }

  void
  CopyTuplesSession::push_null_field() const {
    push_data( &m_null_field_size, sizeof( uint32_t ) );
  }

  void
  CopyTuplesSession::push_trailing() const {
      push_data( &m_trailing_mark, sizeof( uint16_t ) );
  }

} // namespace PsqlTools::PostgresPQ
