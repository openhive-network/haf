#pragma once

#include "psql_utils/pg_cxx.hpp"


#include <cstdint>
#include <string>

#define spixx_elog(elevel, ...)  \
	ereport(elevel, errmsg_internal(__VA_ARGS__))


typedef uintptr_t Datum;
struct SPITupleTable;

extern "C"
{
  struct TupleDescData;
  typedef TupleDescData* TupleDesc;
  struct HeapTupleData;
  typedef HeapTupleData* HeapTuple;
  int SPI_connect();
  int SPI_finish();
} // extern "C"

#include <string>

namespace spixx
{

struct field
{
  Datum datum;
  bool isNull;

  bool is_null() const noexcept
  {
    return isNull;
  }

  const char * c_str() const
  {
    if (isNull)
    {
      return "";
    }

    return text_to_cstring(DatumGetTextP(datum));

  }

    // Templated as<T> method required by field_model
    template<typename T> T as() const;


 
};



template<>
inline std::string_view field::as<std::string_view>() const
{
  return {};//mtlk todo
}


template<>
inline std::basic_string<std::byte> field::as<std::basic_string<std::byte>>() const
{
  return {};//mtlk todo
}




class binarystring
{
private:
  const field& fld;

public:
  explicit binarystring(const field&);

  using char_type = unsigned char;
  using value_type = std::char_traits<char_type>::char_type;
  using size_type = std::size_t;
  [[nodiscard]] value_type const* data() const noexcept;
  [[nodiscard]] size_type size() const noexcept;
};

class row
{
protected:
  HeapTuple tuple;

private:
  TupleDesc tupdesc;

public:
  row(HeapTuple t, TupleDesc td) : tuple(t), tupdesc(td) {}


  field operator[](const std::string &key) const
  {
    int col = SPI_fnumber(tupdesc, key.c_str());
    if (col <= 0)
    {
      spixx_elog(ERROR, "Column not found");
    }
    bool isN;
    Datum datum = SPI_getbinval(tuple, tupdesc, col, &isN);
    return field{datum, isN};
  }

  
  
  
  

};

// The iterator is also the row - it mimics the pqxx behavior where
// you don't need to use dereferencing to access row members on the result iterator
class const_result_iterator
{
private:
  SPITupleTable* tuptable;
  int index;

public:
  explicit const_result_iterator(SPITupleTable* tt, int idx);
  const_result_iterator();

  const_result_iterator& operator++();

  [[nodiscard]] bool operator!=(const_result_iterator const& i) const;
  [[nodiscard]] bool operator==(const_result_iterator const& i) const;
  row operator*() const;
};

class result
{
private:
  SPITupleTable* tuptable;
  uint64_t proc;

public:
  result();
  result(SPITupleTable* t, TupleDesc td, uint64_t p);

  using const_iterator = const_result_iterator;
  [[nodiscard]] const_iterator end() const noexcept;
  [[nodiscard]] bool empty() const noexcept;
  [[nodiscard]] const_iterator begin() const noexcept;
  row operator[](size_t i) const noexcept;

  void display_column_names_and_types(const std::string& label) const;
};

result execute_query(const std::string& query);

}  // namespace spixx
