#pragma once


#define SPIXX_PURE __attribute__((pure))


#include "postgres.h"
#include "executor/spi.h"
#include "catalog/pg_type.h"
#include "access/tupdesc.h"
#include <string>

namespace spixx {

class field {
public:
    Datum datum;
public:    
    bool isNull;

public:
    [[nodiscard]] bool is_null() const noexcept;

    [[nodiscard]] const char *c_str() const;

public:
    uint32_t as_uint32_t() const;
    int as_int() const;
    int64_t as_int64_t() const;
};



class binarystring {
private:
    const field& fld;

public:
    [[deprecated("Use std::byte for binary data.")]]
    explicit binarystring(const field&);

    using char_type = unsigned char;
    using value_type = std::char_traits<char_type>::char_type;
    using size_type = std::size_t;
    [[nodiscard]] value_type const *data() const noexcept;
    [[nodiscard]] size_type size() const noexcept;
};

class row {
private:
    HeapTuple tuple;
    TupleDesc tupdesc;

public:
    row(HeapTuple t, TupleDesc td);
    field operator[](const std::string& key) const;
};

class const_result_iterator : public row {
private:
    SPITupleTable *tuptable;
    int index;

public:
    const_result_iterator(SPITupleTable *tt, int idx);
    const_result_iterator();


    const_result_iterator& operator++();

    [[nodiscard]] bool operator!=(const_result_iterator const& i) const;
    [[nodiscard]] bool operator==(const_result_iterator const& i) const;
    row operator*() const;
};

class result {
private:
    SPITupleTable *tuptable;
    uint64 proc;

public:
    result();
    result(SPITupleTable *t, TupleDesc td, uint64 p);

    using const_iterator = const_result_iterator;
    [[nodiscard]] const_iterator end() const noexcept;
    [[nodiscard]] bool empty() const noexcept;
    [[nodiscard]] const_iterator begin() const noexcept;
    row operator[](size_t i) const noexcept;
};

result execute_query(const std::string& query);

}  // namespace spixx
