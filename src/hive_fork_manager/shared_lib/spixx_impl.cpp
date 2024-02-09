#include "spixx_impl.hpp"

#include "spixx.hpp"
#include "psql_utils/pg_cxx.hpp"


namespace spixx 
{

template<> uint32_t field::as<uint32_t>() const
{
  if (is_null())
  {
    spixx_elog(ERROR, "Attempted conversion of NULL field to uint32_t.");
  }
  return DatumGetUInt32(datum);
}

template<> int field::as<int>() const
{
   if (is_null())
  {
    spixx_elog(ERROR, "Attempted conversion of NULL field to int.");
  }
  return DatumGetInt32(datum);
}

template<> int64_t field::as<int64_t>() const
{
  if (is_null())
  {
    spixx_elog(ERROR, "Attempted conversion of NULL field to int64_t.");
  }
  return DatumGetInt64(datum);
}


const_result_iterator::const_result_iterator()
    : tuptable(nullptr), index(0) {}

const_result_iterator::const_result_iterator(SPITupleTable *tt, int idx)
    : tuptable(tt), index(idx) {}

const_result_iterator &const_result_iterator::operator++()
{
  index++;
  return *this;
}

bool const_result_iterator::operator!=(const_result_iterator const &i) const
{
  return index != i.index;
}

bool const_result_iterator::operator==(const_result_iterator const &i) const
{
  return index == i.index;
}

row const_result_iterator::operator*() const
{
  return row(tuptable->vals[index], tuptable->tupdesc);
}

result::result() : tuptable(nullptr), proc(0) {}

result::result(SPITupleTable *t, TupleDesc td, uint64 p) : tuptable(t), proc(p) {}

result::const_iterator result::end() const noexcept
{
  return const_iterator(tuptable, proc);
}

bool result::empty() const noexcept
{
  return proc == 0;
}

result::const_iterator result::begin() const noexcept
{
  return const_iterator(tuptable, 0);
}

row result::operator[](size_t i) const noexcept
{
  if (i >= proc)
  {
    spixx_elog(ERROR, "Index out of bounds");
  }
  return row(tuptable->vals[i], tuptable->tupdesc);
}

result execute_query(const std::string &query)
{

  int ret = SPI_exec(query.c_str(), 0);
  FC_ASSERT(ret == SPI_OK_SELECT);
  if (ret != SPI_OK_SELECT)
  {
    SPI_finish();
    spixx_elog(ERROR, "Failed executing query");
  }
  return {SPI_tuptable, SPI_tuptable->tupdesc, SPI_processed};
}


postgres_database_helper::postgres_database_helper(const char* url)  
{
}

postgres_database_helper::~postgres_database_helper()
{
} 

spixx::result postgres_database_helper::execute_query(const std::string& query)
{
  spixx::result query_result = spixx::execute_query(query);
  return query_result;
  // pxx::result res(query_result);
  // return res;
}

postgres_database_helper::connect_guard::connect_guard()
{
  if(SPI_connect() != SPI_OK_CONNECT)
  {
    spixx_elog(ERROR, "Cannot establish SPI connection.");
  }
}

postgres_database_helper::connect_guard::~connect_guard()
{
  SPI_finish();
}

} // namespace spixx 

#ifndef NDEBUG

#include <iostream>
using std::cout, std::endl;
#include <unistd.h>
#include <iomanip>

namespace spixx 
{


void display_column_names_and_types(const result& recordset, const std::string &label)
{
  if (!recordset.tuptable || !recordset.tuptable->tupdesc)
  {
    std::cout << "No column descriptions available." << std::endl;
    return;
  }

  TupleDesc tupdesc = recordset.tuptable->tupdesc;

  std::cout << label << " column names:" << std::endl;
  for (int col = 0; col < tupdesc->natts; ++col)
  {
    if (!tupdesc->attrs[col].attisdropped)
    {
      std::cout << "    " << tupdesc->attrs[col].attname.data;

      char *type_name = SPI_gettype(tupdesc, col + 1); // SPI column indexing starts from 1
      Oid type_oid = tupdesc->attrs[col].atttypid;

      if (type_name)
      {
        std::cout << " (" << type_name << ")" << std::endl;
        SPI_pfree(type_name);
      }
      else
      {
        std::cout << " (Unknown type OID: " << type_oid << ")" << std::endl;
      }
    }
  }
}


void display_type_info(const row& r, const std::string &key)
{
  int col = SPI_fnumber(r.tupdesc, key.c_str());
  if (col <= 0)
  {
    spixx_elog(ERROR, "Column not found");
  }

  //BELOW printing type internals
  {
    Oid type_oid;
    char* type_name;

    type_oid = SPI_gettypeid(r.tupdesc, col);

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
}


} // namespace spixx
#endif// NDEBUG
