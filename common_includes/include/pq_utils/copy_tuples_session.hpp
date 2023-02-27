#pragma once

#include "include/pq_utils/copy_session.hpp"
#include <memory>

extern "C" {
  struct HeapTupleData;
  struct tupleDesc;
  typedef tupleDesc* TupleDesc;
  typedef HeapTupleData *HeapTuple;
  typedef struct varlena bytea;
} // extern "C"

namespace PsqlTools::PostgresPQ {

  class CopyTuplesSession : public CopySession {
  public:
    CopyTuplesSession( std::shared_ptr< pg_conn > _connection, const std::string& _table, const std::vector< std::string >& _columns );
    ~CopyTuplesSession();

    void push_tuple( bytea* _encoded_with_copy_tuple );
    void push_tuple_as_next_column( const HeapTupleData& _tuple, const TupleDesc& _tupleDesc );

    void push_tuple_header( uint16_t _number_of_fields );
    void push_null_field() const;
  private:
    void push_tuple_to_next_field( const HeapTupleData& _tuple );

  private:
    void push_tuple_header( const TupleDesc& _tupleDesc );
    void push_trailing() const;

  private:
    const uint32_t m_null_field_size;
    const uint16_t m_trailing_mark;
  };

} // namespace PsqlTools::PostgresPQ
