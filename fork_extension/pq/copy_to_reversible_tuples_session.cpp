#include "include/pq/copy_to_reversible_tuples_session.hpp"

#include "include/exceptions.hpp"
#include "include/postgres_includes.hpp"
#include "include/sql_commands.hpp"

#include <cassert>
#include <exception>
#include <vector>

namespace ForkExtension::PostgresPQ {
    int32_t CopyToReversibleTuplesTable::m_tuple_id = 0;

    CopyToReversibleTuplesTable::CopyToReversibleTuplesTable( std::shared_ptr< pg_conn > _connection )
  : CopyTuplesSession( _connection, TUPLES_TABLE_NAME )
  {
  }

  CopyToReversibleTuplesTable::~CopyToReversibleTuplesTable() {}

  void
  CopyToReversibleTuplesTable::push_delete(const std::string& _table_name, const HeapTupleData& _deleted_tuple, const TupleDesc& _tuple_desc ) {
    if ( _table_name.empty() ) {
      THROW_RUNTIME_ERROR("Empty table name");
    }

    push_tuple_header();
    push_id_field(); // id
    push_table_name( _table_name ); // table name
    push_operation( OperationType::DELETE );
    push_tuple_as_next_column(_deleted_tuple, _tuple_desc ); // old tuple
    push_null_field(); // new tuple
  }

  void
  CopyToReversibleTuplesTable::push_insert(const std::string& _table_name, const HeapTupleData& _inserted_tuple, const TupleDesc& _tuple_desc ) {
    if ( _table_name.empty() ) {
      THROW_RUNTIME_ERROR("Empty table name");
    }

    push_tuple_header();
    push_id_field();
    push_table_name( _table_name );
    push_operation( OperationType::INSERT );
    push_null_field(); // old tuple - before insert there was no tuple
    push_tuple_as_next_column( _inserted_tuple, _tuple_desc ); // new tuple
  }

  void
  CopyToReversibleTuplesTable::push_update( const std::string& _table_name, const HeapTupleData& _old_tuple, const HeapTupleData& _new_tuple, const TupleDesc& _tuple_desc ) {
    if ( _table_name.empty() ) {
      THROW_RUNTIME_ERROR("Empty table name");
    }

    push_tuple_header();
    push_id_field();
    push_table_name( _table_name );
    push_operation( OperationType::UPDATE );
    push_tuple_as_next_column( _old_tuple, _tuple_desc ); // old tuple
    push_tuple_as_next_column( _new_tuple, _tuple_desc ); // new tuple
  }

  void
  CopyToReversibleTuplesTable::push_tuple_header() {
    static constexpr uint16_t number_of_columns = 5; // id, table, operation, prev, next
    CopyTuplesSession::push_tuple_header( number_of_columns );
  }

  void
  CopyToReversibleTuplesTable::push_id_field() {
    static const uint32_t id_size = htonl( sizeof( uint32_t ) );
    push_data( &id_size, sizeof( uint32_t ) );
    auto tuple_id = htonl( m_tuple_id );
    push_data( &tuple_id, sizeof( uint32_t ) );
    ++m_tuple_id;
  }

  void
  CopyToReversibleTuplesTable::push_table_name( const std::string& _table_name ) {
    uint32_t name_size = htonl( _table_name.size() );
    push_data( &name_size, sizeof( uint32_t ) );
    push_data( _table_name.c_str(), _table_name.size()  );
  }

  void
  CopyToReversibleTuplesTable::push_operation( OperationType _operation) {
      uint32_t operation_size = htonl( sizeof( uint16_t ) );
      auto operation = htons( static_cast<uint16_t>( _operation ) );
      push_data( &operation_size, sizeof( uint32_t ) );
      push_data( &operation, sizeof( uint16_t )  );
  }

} // namespace ForkExtension::PostgresPQ
