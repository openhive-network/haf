#pragma once

#include "include/psql_utils/postgres_includes.hpp"

#include <boost/optional.hpp>

namespace PsqlTools::PsqlUtils {

  /* Tuple in copy format
   * | number of fields | field 1 size(B) |  field 1 value  | field 2 size(B) | field 2 value   | ...
   * |        16b       |        32b      | field 1 size(B) |      32b        | field 2 size(B) | ...
   */
  class TuplesFieldIterator {
  public:
    class Field {
      public:
        Field( uint8_t* _value, uint32_t _size ) : m_value( _value ), m_size( _size ) {}

        uint8_t* getValue() const { return m_value;}
        uint32_t getSize() const { return m_size; }

        explicit operator bool() const { return m_value || m_size; }
        bool isNullValue() const { return m_size == 0xFFFFFFFF; }
      private:
        uint8_t* m_value;
        uint32_t m_size;
    };

    TuplesFieldIterator( bytea* _tuple_in_copy_format );
    ~TuplesFieldIterator() = default;
    TuplesFieldIterator( TuplesFieldIterator& ) = delete;
    TuplesFieldIterator( TuplesFieldIterator&& ) = delete;
    TuplesFieldIterator& operator=( TuplesFieldIterator& ) = delete;
    TuplesFieldIterator& operator=( TuplesFieldIterator&& ) = delete;

    boost::optional< Field > next();

  private:
    bool atEnd() const;
    Field getField() const;

  private:
    static constexpr auto NUMBER_OF_FIELDS_SIZE = 2u; // Bytes
    static constexpr auto FIELD_SIZE_SIZE = 4u; // Bytes
    uint8_t* m_tuple_bytes;
    uint16_t m_number_of_fields;
    uint32_t m_tuple_size;
    uint16_t m_current_field_number;
    uint8_t* m_current_field;
  };

} // namespace PsqlTools::PsqlUtils
