#include <string>
#include <memory>

#define PQXX_PURE

namespace pxx
{

using result_size_type = int;
using row_size_type = int;


struct field
{
  [[nodiscard]] PQXX_PURE char const *c_str() const &;
  [[nodiscard]] PQXX_PURE bool is_null() const noexcept;

  template<typename T> T as() const
  {
    // if (is_null())
    // {
    //   if constexpr (not nullness<T>::has_null)
    //     internal::throw_null_conversion(type_name<T>);
    //   else
    //     return nullness<T>::null();
    // }
    // else
    // {
    //   return from_string<T>(this->view());
    // }
    return T();
  }

};

struct binarystring
{
};

struct row
{
  using reference = field;

  //[[nodiscard]] reference operator[](zview col_name) const;
  [[nodiscard]] reference operator[](const std::string& col_name) const;
  int alamakota();
  //[[nodiscard]] reference operator[](const char [4]) const;

};

struct const_result_iterator : public row
{
  using reference = row;
  [[nodiscard]] bool operator==(const_result_iterator const &i) const;
  [[nodiscard]] bool operator!=(const_result_iterator const &i) const;
  const_result_iterator operator++(int);
  const_result_iterator &operator++();
  [[nodiscard]] reference operator*() const { return *this; }
};



struct result
{
  using size_type = result_size_type;
  using const_iterator = const_result_iterator;

  [[nodiscard]] row operator[](size_type i) const noexcept;
  [[nodiscard]] const_iterator begin() const noexcept;
  [[nodiscard]] inline const_iterator end() const noexcept;
  [[nodiscard]] PQXX_PURE bool empty() const noexcept;


};


}  // namespace spixx
