#pragma once

#include <string>
#include <memory>
#include <any>

#define PQXX_PURE

// This is the common interface for pqxx and SPI wrappeer (spixx)
// it can be used with value semantics, not pointer or reference semantics
// according to Sean Parent's 
// Value Semantics and Concept-based Polymorphism
// It has some drawbacks thou e.g.:  it is hard to expose the templated member interface  

namespace pxx
{

struct timestamp_wo_tz_type
{
    std::string val;
};

inline bool operator != (const timestamp_wo_tz_type& a, const timestamp_wo_tz_type& b)
{
    return a.val != b.val;
}

inline std::ostream& operator<<(std::ostream& os, const timestamp_wo_tz_type& timestamp)
{
    return os << timestamp.val;
}

struct jsonb_string
{
    std::string val;
};

inline bool operator != (const jsonb_string& a, const jsonb_string& b)
{
    return a.val != b.val;
}

inline std::ostream& operator<<(std::ostream& os, const jsonb_string& timestamp)
{
    return os << timestamp.val;
}

using result_size_type = int;
using row_size_type = int;

struct field;

struct field_concept
{
  virtual char const *c_str() const & = 0;
  virtual bool is_null() const noexcept = 0;

  // Cannot expose as<T> directly because C++ does not allow templated virtuals
  // so casting to std::any
  virtual std::any as(const std::type_info& type) const = 0;
  
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
      using operation_bin_type = std::basic_string<std::byte>;

      // Cannot use switch case with type_info
      // and the visitor/variant does not bring any advantage here
      // so if else used
      if (type == typeid(uint32_t)) 
      {
          return data.template as<uint32_t>();
      }
      else if(type == typeid(jsonb_string))
      {
        return data. template as<jsonb_string>();
      }
      else if(type == typeid(int))
      {
        return data. template as<int>();
      }
      else if(type == typeid(int64_t))
      {
        return data. template as<int64_t>();
      }
      else if(type == typeid(operation_bin_type))
      {
        return data. template as<operation_bin_type>();
      }
      else if(type == typeid(int64_t))
      {
        return data. template as<int64_t>();
      }
      else if(type == typeid(std::string_view))
      {
        return data. template as<std::string_view>();
      }
      else if(type == typeid(pxx::timestamp_wo_tz_type))
      {
        return data. template as<pxx::timestamp_wo_tz_type>();
      }
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
  virtual field operator[](const std::string& col_name) const = 0;
};

template<typename T>
struct row_model : row_concept 
{
    T data;
    row_model(T data) : data(std::move(data)) {}

    pxx::field operator[](const std::string& key) const override 
    {
        return data[key];
    }
};


// Type-erased wrapper for row
class row 
{
    std::unique_ptr<const row_concept> self_;
public:
    template<typename T>
    row(T x) : self_(std::make_unique<row_model<T>>(std::move(x))) {}

    pxx::field operator[](const std::string& key) const 
    {
        return (*self_)[key];
    }

};


struct const_result_iterator_concept
{
  virtual ~const_result_iterator_concept() = default;
  virtual const_result_iterator_concept& operator++() = 0;
  virtual row  operator*() const = 0;
  virtual bool is_equal(const const_result_iterator_concept& other) const = 0;
  virtual bool is_not_equal(const const_result_iterator_concept& other) const = 0;
};


template<typename T>
struct const_result_iterator_model : const_result_iterator_concept
{
  T data;
  const_result_iterator_model(T data) : data(std::move(data)) {}

  const_result_iterator_concept& operator++() override
  {
    ++data;
    return *this;
  }

  bool is_equal(const const_result_iterator_concept& other) const override
  {
    const auto* other_ptr = static_cast<const const_result_iterator_model<T>*>(&other);
    if(other_ptr) 
    {
      return data == other_ptr->data;
    }
    return false;
  }

  bool is_not_equal(const const_result_iterator_concept& other) const override
  {
    const auto* other_ptr = static_cast<const const_result_iterator_model<T>*>(&other);
    if(other_ptr) 
    {
      return data != other_ptr->data;
    }
    return true;
  }

  row  operator*() const override { return *data; }
};

// Type-erased wrapper for const_result_iterator
class const_result_iterator 
{
  std::unique_ptr<const_result_iterator_concept> self_;
public:
  template<typename T>
  const_result_iterator(T x) : self_(std::make_unique<const_result_iterator_model<T>>(std::move(x))) {}
  const_result_iterator() {}


  const_result_iterator& operator++()
  {
    ++(*self_);
    return *this;
  }

  bool operator==(const const_result_iterator& other) const
  {
    return self_->is_equal(*other.self_);
  }

  bool operator!=(const const_result_iterator& other) const
  {
    return self_->is_not_equal(*other.self_);
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
struct result_model : result_concept 
{
    T data;
    result_model(T data) : data(std::move(data)) {}

    const_result_iterator begin() const noexcept override 
    {
        return data.begin();
    }

    const_result_iterator end() const noexcept override 
    {
        return data.end();
    }

    bool empty() const noexcept override 
    {
        return data.empty();
    }



};

// Type-erased wrapper for pxx::result
class result 
{
    std::unique_ptr<const result_concept> self_;
public:
    template<typename T>
    result(T x) : self_(std::make_unique<result_model<T>>(std::move(x))) {}
    result(){ } //mtlk todo ??

    const_result_iterator begin() const noexcept 
    {
        return self_->begin();
    }

    const_result_iterator end() const noexcept 
    {
        return self_->end();
    }

    bool empty() const noexcept 
    {
        return self_->empty();
    }

};



}  // namespace pxx
