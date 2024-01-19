#include "spixx.hpp"

#include "psql_utils/pg_cxx.hpp"


#include <iomanip>
#include <iostream>


#define spixx_elog(elevel, ...)  \
	ereport(elevel, errmsg_internal(__VA_ARGS__))


namespace spixx 
{

uint32_t field::as_uint32_t() const
{
  if (is_null())
  {
    spixx_elog(ERROR, "Attempted conversion of NULL field to uint32_t.");
  }
  return DatumGetUInt32(datum);
}

int field::as_int() const
{
  if (is_null())
  {
    spixx_elog(ERROR, "Attempted conversion of NULL field to int.");
  }
  return DatumGetInt32(datum);
}

int64_t field::as_int64_t() const
{
  if (is_null())
  {
    spixx_elog(ERROR, "Attempted conversion of NULL field to int64_t.");
  }
  return DatumGetInt64(datum);
}

size_t field::bytea_length() const
{
  if (isNull)
  {
    return 0;
  }

  bytea *raw_data = DatumGetByteaP(datum);

  return VARSIZE(raw_data) - VARHDRSZ;
}

std::string field::as_hex_string() const
{
  const char *bytea_data = c_str();
  size_t length = bytea_length();

  std::ostringstream oss;
  for (size_t i = 0; i < length; i++)
  {
    oss << std::hex << std::setw(2) << std::setfill('0') << (static_cast<int>(bytea_data[i]) & 0xFF);
  }

  return oss.str();
}

std::string field::as_timestamp_string() const
{
  return c_str();
}

bool field::is_null() const noexcept
{
  return isNull;
}

const char *field::c_str() const
{
  if (isNull)
  {
    return "";
  }

  return text_to_cstring(DatumGetTextP(datum));
}

binarystring::binarystring(const field &f) : fld(f) {}

binarystring::value_type const *binarystring::data() const noexcept
{
  return (value_type const *)VARDATA_ANY(fld.datum);
}

binarystring::size_type binarystring::size() const noexcept
{
  return VARSIZE_ANY_EXHDR(fld.datum);
}

row::row(HeapTuple t, TupleDesc td) : tuple(t), tupdesc(td) {}

field row::operator[](const std::string &key) const
{
  int col = SPI_fnumber(tupdesc, key.c_str());
  if (col <= 0)
  {
    std::string msg = std::string("Column ") + key + " not found";
    spixx_elog(ERROR, msg.c_str());
  }
  bool isN;
  Datum datum = SPI_getbinval(tuple, tupdesc, col, &isN);
  return field{datum, isN};
}

std::string row::get_value(const std::string &key) const
{
  int col = SPI_fnumber(tupdesc, key.c_str());
  if (col <= 0)
  {
    std::string msg = std::string("Column ") + key + " not found";
    spixx_elog(ERROR, msg.c_str());
  }
  char *ch = SPI_getvalue(tuple, tupdesc, col);
  std::string value(ch);
  pfree(ch);
  return value;
}

const_result_iterator::const_result_iterator()
    : row(nullptr, nullptr), tuptable(nullptr), index(0) {}

const_result_iterator::const_result_iterator(SPITupleTable *tt, int idx)
    : row(tt->vals[idx], tt->tupdesc), tuptable(tt), index(idx) {}

const_result_iterator &const_result_iterator::operator++()
{
  index++;
  tuple = tuptable->vals[index];
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

void result::display_column_names_and_types(const std::string &label) const
{
  if (!tuptable || !tuptable->tupdesc)
  {
    std::cout << "No column descriptions available." << std::endl;
    return;
  }

  TupleDesc tupdesc = tuptable->tupdesc;

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
}
