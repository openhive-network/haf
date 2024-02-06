#include "spixx_impl.hpp"

#include "spixx.hpp"
#include "psql_utils/pg_cxx.hpp"


#include <iostream>
using std::cout, std::endl;
#include <unistd.h>
#include <iomanip>
///////////////////////////////////////////////////// wklerjone begin mtlk todo


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

#ifndef NDEBUG
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
#endif

////////////////////////////////////////////////////////////////////////// wklejone mtlk todo end


postgres_database_helper_spi::postgres_database_helper_spi(const char* url)  
{
}

postgres_database_helper_spi::~postgres_database_helper_spi()
{
} 

pxx::result postgres_database_helper_spi::execute_query(const std::string& query)
{
  spixx::result query_result = spixx::execute_query(query);
  pxx::result res(query_result);
  return res;
}

postgres_database_helper_spi::spi_connect_guard::spi_connect_guard()
{
  if(SPI_connect() != SPI_OK_CONNECT)
  {
    spixx_elog(ERROR, "Cannot establish SPI connection.");
  }
}

postgres_database_helper_spi::spi_connect_guard::~spi_connect_guard()
{
  SPI_finish();
}

}
