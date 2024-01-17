#pragma once

#include <cstdint>

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

  [[nodiscard]] bool is_null() const noexcept;
  [[nodiscard]] const char* c_str() const;

  [[nodiscard]] uint32_t as_uint32_t() const;
  [[nodiscard]] int as_int() const;
  [[nodiscard]] int64_t as_int64_t() const;
  [[nodiscard]] std::string as_hex_string() const;
  [[nodiscard]] std::string as_timestamp_string() const;

private:
  [[nodiscard]] size_t bytea_length() const;
};

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
  row(HeapTuple t, TupleDesc td);
  field operator[](const std::string& key) const;
  std::string get_value(const std::string& key) const;
};

// The iterator is also the row - it mimics the pqxx behavior where
// you don't need to use dereferencing to access row members on the result iterator
class const_result_iterator : public row
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
