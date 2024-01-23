#pragma once

#include "psql_utils/pg_cxx.hpp"


#include <cstdint>
#include <string>
#include <iostream>

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

  // char* c_str = TextDatumGetCString(datum);
  // std::string_view my_string_view(c_str);
  // return my_string_view;

  text* text_ptr = DatumGetTextP(datum);

  char* cstr = VARDATA(text_ptr);
  int length = VARSIZE(text_ptr) - VARHDRSZ;

  std::string_view my_string_view(cstr, length);
  return my_string_view;
}


template<>
inline std::basic_string<std::byte> field::as<std::basic_string<std::byte>>() const
{
  throw std::bad_function_call();
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

{


Oid type_oid;
char *type_name;

// Get the OID of the column's type
type_oid = SPI_gettypeid(tupdesc, col);

if (type_oid != InvalidOid)
{
    // Get the name of the type
    type_name = format_type_be(type_oid);
    printf("Column type: %s", type_name);

    // If format_type_be allocates a new string, remember to pfree it
    pfree(type_name);

    HeapTuple type_tuple;
    Form_pg_type type_form;


    // Retrieve the type tuple from the system catalog
    type_tuple = SearchSysCache1(TYPEOID, ObjectIdGetDatum(type_oid));
    if (HeapTupleIsValid(type_tuple))
    {
        type_form = (Form_pg_type) GETSTRUCT(type_tuple);

        // Type Name
        std::cout << "Type name: " << NameStr(type_form->typname) << std::endl;

        // Type Category and Preferred State
        char typtype = type_form->typtype;
        bool typispreferred = type_form->typispreferred;
        std::cout << "Type category: " << typtype << std::endl;
        std::cout << "Type preferred: " << (typispreferred ? "yes" : "no") << std::endl;

        // Type Length
        int16 typlen = type_form->typlen;
        std::cout << "Type length: " << typlen << std::endl;

        // Type Alignment
        char typalign = type_form->typalign;
        std::cout << "Type alignment: " << typalign << std::endl;

        // // Type Default Value (if any)
        // if (type_form->typdefaultbin)
        // {
        //     Datum typdefault = SysCacheGetAttr(TYPEOID, type_tuple, Anum_pg_type_typdefault, NULL);
        //     std::cout << "Type default value: " << TextDatumGetCString(typdefault) << std::endl;
        // }
        // else
        // {
        //     std::cout << "No default value for type" << std::endl;
        // }

        // Type Input and Output Functions
        Oid typinput = type_form->typinput;
        Oid typoutput = type_form->typoutput;
        std::cout << "Type input function OID: " << typinput << std::endl;
        std::cout << "Type output function OID: " << typoutput << std::endl;

        // Element Type for Arrays (if it's an array type)
        Oid typelem = type_form->typelem;
        if (typelem != InvalidOid)
        {
            std::cout << "Element type OID: " << typelem << std::endl;
        }
        else
        {
            std::cout << "Not an array type" << std::endl;
        }

        // Delimiter for Arrays
        char typdelim = type_form->typdelim;
        std::cout << "Type delimiter: " << typdelim << std::endl;

        ReleaseSysCache(type_tuple);
    }
    else
    {
        std::cout << "Type not found" << std::endl;
    }



}
else
{
    spixx_elog(ERROR, "Invalid column index or type OID");
}

  }
// {
//     Oid type_oid;
//   char *type_name_str;
//   int16 typlen;
//   bool typbyval;
//   char typalign;

//   /* Get the OID of the data type of the column */
//   type_oid = get_atttype(tupdesc, col);

//   /* Get the name of the type as a string */
//   type_name_str = format_type_be(type_oid);

//   /* Get additional type information */
//   get_typlenbyvalalign(type_oid, &typlen, &typbyval, &typalign);

//   /* Now you can use type_oid, type_name_str, typlen, typbyval, and typalign */
//   /* Don't forget to free type_name_str if it's dynamically allocated */

//   std::cout << "here\n";

// }

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

#include "pxx.hpp"

#include "utils/timestamp.h"

namespace spixx
{
template<>
inline pxx::timestamp_wo_tz_type field::as<pxx::timestamp_wo_tz_type>() const
{

   Timestamp timestamp = DatumGetTimestamp(datum);

    /* Convert Timestamp to a human-readable string */
    char *timestamp_string = DatumGetCString(DirectFunctionCall1(timestamp_out, TimestampGetDatum(timestamp)));

    // timestamp = (Timestamp)(datum);

    // timestamp_string = DatumGetCString(DirectFunctionCall1(timestamp_out, (Datum)(timestamp)));

    printf("Timestamp: %s", timestamp_string);



  auto res =  pxx::timestamp_wo_tz_type{std::string(timestamp_string)};

      /* Clean up and return */
  pfree(timestamp_string);
  return res;
}
}  // namespace spixx

