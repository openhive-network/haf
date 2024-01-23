#include <string>
#include <memory>
#include <any>

#define PQXX_PURE

namespace pxx
{

using result_size_type = int;
using row_size_type = int;

struct field;

struct field_concept
{
  virtual char const *c_str() const & = 0;
  virtual bool is_null() const noexcept = 0;

  virtual std::any as(const std::type_info& type) const = 0;
  
  // {
  //   // if (is_null())
  //   // {
  //   //   if constexpr (not nullness<T>::has_null)
  //   //     internal::throw_null_conversion(type_name<T>);
  //   //   else
  //   //     return nullness<T>::null();
  //   // }
  //   // else
  //   // {
  //   //   return from_string<T>(this->view());
  //   // }
  //   return T();
  // }

};

template<typename T>
struct field_model : field_concept
{
  T data;
  field_model(T data) : data(std::move(data)) {}
  virtual char const *c_str() const & override
  {
    return data.template c_str();
  }
  
  virtual bool is_null() const noexcept override
  {
    return data.is_null();
  }

  std::any as(const std::type_info& type) const override 
  {
      if (type == typeid(uint32_t))
      {
          return data.template as<uint32_t>();
      }
      // Add other types as needed
      throw std::bad_cast();
  }

};

class field 
{
    std::unique_ptr<const field_concept> self_;

public:
    template<typename T>
    field(T x) : self_(std::make_unique<field_model<T>>(std::move(x))) {}

    bool is_null() const noexcept { return self_->is_null(); }
    
    const char* c_str() const { return self_->c_str(); }

    template<typename T>
    T as() const
    {
        return std::any_cast<T>(self_->as(typeid(T)));
    }
};


struct row;
struct row_concept
{
  

  //[[nodiscard]] reference operator[](zview col_name) const;
  virtual field operator[](const std::string& col_name) const = 0;
  //[[nodiscard]] reference operator[](const char [4]) const;

};


// Model for row
template<typename T>
struct row_model : row_concept {
    T data;
    row_model(T data) : data(std::move(data)) {}

    pxx::field operator[](const std::string& key) const override {
        return data[key];
    }
};


// Type-erased wrapper for row
class row {
    std::unique_ptr<const row_concept> self_;
public:
    template<typename T>
    row(T x) : self_(std::make_unique<row_model<T>>(std::move(x))) {}

    pxx::field operator[](const std::string& key) const {
        return (*self_)[key];
    }

};


struct const_result_iterator_concept {
    virtual ~const_result_iterator_concept() = default;

    virtual const_result_iterator_concept& operator++() = 0;
    virtual bool operator!=(const const_result_iterator_concept& other) const = 0;
    virtual bool operator==(const const_result_iterator_concept& other) const = 0;
    virtual row  operator*() const = 0;
};




template<typename T>
struct const_result_iterator_model : const_result_iterator_concept {
    T data;
    const_result_iterator_model(T data) : data(std::move(data)) {}

    const_result_iterator_concept& operator++() override {
        ++data;
        return *this;
    }

    bool operator!=(const const_result_iterator_concept& other) const override {
        return data.operator!=(other);
    }

    bool operator==(const const_result_iterator_concept& other) const override {
        return data.operator==(other);
    }

    row  operator*() const override { return *data; } 
};

// Type-erased wrapper for const_result_iterator
class const_result_iterator {
    std::unique_ptr<const_result_iterator_concept> self_;
public:
    template<typename T>
    const_result_iterator(T x) : self_(std::make_unique<const_result_iterator_model<T>>(std::move(x))) {}
    const_result_iterator(){} //mtlk todo ??


    const_result_iterator& operator++() {
        ++(*self_);
        return *this;
    }

    bool operator!=(const const_result_iterator& other) const {
        return *self_ != *other.self_;
    }

    bool operator==(const const_result_iterator& other) const {
        return *self_ == *other.self_;
    }


  row operator*() const { return **self_; } 
};



// Concept for pxx::result
struct result_concept 
{
    virtual ~result_concept() = default;
    virtual const_result_iterator begin() const noexcept = 0;
    virtual const_result_iterator end() const noexcept = 0;
    virtual bool empty() const noexcept = 0;
};


// Model for pxx::result
template<typename T>
struct result_model : result_concept {
    T data;
    result_model(T data) : data(std::move(data)) {}

    const_result_iterator begin() const noexcept override {
        return data.begin();
    }

    const_result_iterator end() const noexcept override {
        return data.end();
    }

    bool empty() const noexcept override {
        return data.empty();
    }



};

// Type-erased wrapper for pxx::result
class result {
    std::unique_ptr<const result_concept> self_;
public:
    template<typename T>
    result(T x) : self_(std::make_unique<result_model<T>>(std::move(x))) {}
    result(){ } //mtlk todo ??

    const_result_iterator begin() const noexcept {
        return self_->begin();
    }

    const_result_iterator end() const noexcept {
        return self_->end();
    }

    bool empty() const noexcept {
        return self_->empty();
    }



};

// struct result
// {
//   using size_type = result_size_type;
//   using const_iterator = const_result_iterator;

//   [[nodiscard]] row operator[](size_type i) const noexcept;
//   [[nodiscard]] const_iterator begin() const noexcept;
//   [[nodiscard]] inline const_iterator end() const noexcept;
//   [[nodiscard]] PQXX_PURE bool empty() const noexcept;


// };


}  // namespace spixx
