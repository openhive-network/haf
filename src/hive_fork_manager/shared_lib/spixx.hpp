#pragma once

#include "postgres.h"
#include "executor/spi.h"
#include "catalog/pg_type.h"
#include "access/tupdesc.h"
#include <string>


#define SPIXX_PURE __attribute__((pure))


namespace spixx
{
  class field
  {
    public:
    template<typename T> T as() const;
    [[nodiscard]] SPIXX_PURE bool is_null() const noexcept;    
    [[nodiscard]] SPIXX_PURE char const *c_str() const &;

  };

  class binarystring{
    public:
    [[deprecated("Use std::byte for binary data.")]] explicit binarystring(field const &);

    using char_type = unsigned char;
    using value_type = std::char_traits<char_type>::char_type;
    using size_type = std::size_t;
    [[nodiscard]] value_type const *data() const noexcept;
    [[nodiscard]] size_type size() const noexcept;
  };

  class row
  {
    public:
      field operator[](const std::string& key) const;


  };

  class const_result_iterator : public row
  {
    public:
      const_result_iterator &operator++();
      [[nodiscard]] bool operator!=(const_result_iterator const &i) const;
      [[nodiscard]] bool operator==(const_result_iterator const &i) const;

      using reference = row;
      [[nodiscard]] reference operator*() const;
  };


  class result{
    public:
    result();
    result(
      SPITupleTable *tuptable,
      TupleDesc tupdesc,
      uint64 proc


    // SPITupleTable *tuptable = SPI_tuptable;
    // TupleDesc tupdesc = tuptable->tupdesc; (void)tupdesc;
    // uint64 proc = SPI_processed;

    );
    using const_iterator = const_result_iterator;    
    [[nodiscard]] inline const_iterator end() const noexcept;
    [[nodiscard]] SPIXX_PURE bool empty() const noexcept;
    [[nodiscard]] const_iterator begin() const noexcept;
    
    using size_type = std::size_t;
    [[nodiscard]] row operator[](size_type i) const noexcept;

  };

  inline result execute_query(const std::string& query)
  {
      int ret = SPI_exec(query.c_str(), 0);
      if (ret != SPI_OK_SELECT)
      {
          //elog(ERROR, "Failed executing query");
      }

      // SPITupleTable *tuptable = SPI_tuptable;
      // TupleDesc tupdesc = tuptable->tupdesc; (void)tupdesc;
      // uint64 proc = SPI_processed;

      return spixx::result(
          SPI_tuptable,
          SPI_tuptable->tupdesc,
          SPI_processed
      );

  }
  
}

