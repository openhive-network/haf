#pragma once

#include "pxx.hpp"
#include "psql_utils/pg_cxx.hpp"

#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"
#include "utils/timestamp.h"

#include <string>
#include <cstddef>
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

  text* text_ptr = DatumGetTextP(datum);

  char* cstr = VARDATA(text_ptr);
  int length = VARSIZE(text_ptr) - VARHDRSZ;

  std::string_view my_string_view(cstr, length);
  return my_string_view;
}


template<>
inline std::basic_string<std::byte> field::as<std::basic_string<std::byte>>() const
{
  bytea *bytea_data = DatumGetByteaP(datum);
  char *data = VARDATA(bytea_data);
  size_t size = VARSIZE(bytea_data) - VARHDRSZ;

  std::basic_string<std::byte> byte_string(reinterpret_cast<std::byte *>(data), size);

  return byte_string;
}



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
    
    #ifndef NDEBUG
    //BELOW printing type internals
    {
      Oid type_oid;
      char* type_name;

      type_oid = SPI_gettypeid(tupdesc, col);

      if (type_oid != InvalidOid) 
      {
        type_name = format_type_be(type_oid);
        printf("Column type: %s", type_name);

        pfree(type_name);

        HeapTuple type_tuple;
        Form_pg_type type_form;

        type_tuple = SearchSysCache1(TYPEOID, ObjectIdGetDatum(type_oid));
        if (HeapTupleIsValid(type_tuple)) {
          type_form = (Form_pg_type)GETSTRUCT(type_tuple);

          std::cout << "Type name: " << NameStr(type_form->typname)
                    << std::endl;

          char typtype = type_form->typtype;
          bool typispreferred = type_form->typispreferred;
          std::cout << "Type category: " << typtype << std::endl;
          std::cout << "Type preferred: " << (typispreferred ? "yes" : "no")
                    << std::endl;

          int16 typlen = type_form->typlen;
          std::cout << "Type length: " << typlen << std::endl;

          char typalign = type_form->typalign;
          std::cout << "Type alignment: " << typalign << std::endl;

          Oid typinput = type_form->typinput;
          Oid typoutput = type_form->typoutput;
          std::cout << "Type input function OID: " << typinput << std::endl;
          std::cout << "Type output function OID: " << typoutput << std::endl;

          Oid typelem = type_form->typelem;
          if(typelem != InvalidOid)
          {
            std::cout << "Element type OID: " << typelem << std::endl;
          }
          else
          {
            std::cout << "Not an array type" << std::endl;
          }

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
    #endif 

  }
};

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

template<>
inline pxx::timestamp_wo_tz_type field::as<pxx::timestamp_wo_tz_type>() const
{

  Timestamp timestamp = DatumGetTimestamp(datum);

  char* timestamp_string = DatumGetCString(DirectFunctionCall1(timestamp_out, TimestampGetDatum(timestamp)));

  auto res = pxx::timestamp_wo_tz_type{ std::string(timestamp_string) };

  pfree(timestamp_string);
  return res;
}

template<>
inline pxx::jsonb_string field::as<pxx::jsonb_string>() const
{
  std::string s;

  if(!isNull)
  {
    Jsonb* jb = DatumGetJsonbP(datum);

    char* j_string = JsonbToCString(NULL, &jb->root, VARSIZE(jb));

    s = (j_string);
    pfree(j_string);
  }

  auto res = pxx::jsonb_string{ s };

  return res;
}

} // namespace spixx

