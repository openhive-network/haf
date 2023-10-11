
#include "spixx.hpp"
#include "utils/builtins.h"  // For text_to_cstring

#include "spixx.hpp"
#include "utils/builtins.h"

// namespace spixx {

// // field implementation


// // field implementation

// // field implementation
// uint32_t field::as_uint32_t() const {
//     if (is_null()) {
//         elog(ERROR, "Attempted conversion of NULL field to uint32_t.");
//     }
//     return DatumGetUInt32(datum);
// }

// int field::as_int() const {
//     if (is_null()) {
//         elog(ERROR, "Attempted conversion of NULL field to int.");
//     }
//     return DatumGetInt32(datum);
// }

// int64_t field::as_int64_t() const {
//     if (is_null()) {
//         elog(ERROR, "Attempted conversion of NULL field to int64_t.");
//     }
//     return DatumGetInt64(datum);
// }


// bool field::is_null() const noexcept 
// {
//     return isNull;
// }

// const char *field::c_str() const {
//     if (isNull) return nullptr;
//     return 0; // mtlk commented text_to_cstring(DatumGetTextP(datum));
// }

// // binarystring implementation
// binarystring::binarystring(const field& f) : fld(f) {}

// binarystring::value_type const *binarystring::data() const noexcept {
//     return (value_type const *) VARDATA_ANY(fld.datum);
// }

// binarystring::size_type binarystring::size() const noexcept {
//     return VARSIZE_ANY_EXHDR(fld.datum);
// }

// // row implementation
// row::row(HeapTuple t, TupleDesc td) : tuple(t), tupdesc(td) {}

// field row::operator[](const std::string& key) const {
//     int col = SPI_fnumber(tupdesc, key.c_str());
//     if (col <= 0) {
//         elog(ERROR, "Column not found");
//     }
//     bool isN;
//     Datum datum;//mtlk COMMENTED  = SPI_getbinval(tuple, tupdesc, col, &isN);
//     return field{datum, isN};
// }

// // const_result_iterator implementation
// const_result_iterator::const_result_iterator(SPITupleTable *tt, int idx)
// : row(tt->vals[idx], tt->tupdesc), tuptable(tt), index(idx) {}

// const_result_iterator& const_result_iterator::operator++() {
//     index++;
//     return *this;
// }

// bool const_result_iterator::operator!=(const_result_iterator const& i) const {
//     return index != i.index;
// }

// bool const_result_iterator::operator==(const_result_iterator const& i) const {
//     return index == i.index;
// }

// row const_result_iterator::operator*() const {
//     return row(tuptable->vals[index], tuptable->tupdesc);
// }

// // result implementation
// result::result() : tuptable(nullptr), proc(0) {}

// result::result(SPITupleTable *t, TupleDesc td, uint64 p) : tuptable(t), proc(p) {}

// result::const_iterator result::end() const noexcept {
//     return const_iterator(tuptable, proc);
// }

// bool result::empty() const noexcept {
//     return proc == 0;
// }

// result::const_iterator result::begin() const noexcept {
//     return const_iterator(tuptable, 0);
// }

// row result::operator[](size_t i) const noexcept {
//     if (i >= proc) {
//         elog(ERROR, "Index out of bounds");
//     }
//     return row(tuptable->vals[i], tuptable->tupdesc);
// }

// // result execute_query(const std::string& query) 
// // {

// //     int ret = SPI_exec(query.c_str(), 0);
// //     if (ret != SPI_OK_SELECT) {
// //         SPI_finish();
// //         elog(ERROR, "Failed executing query");
// //     }

// //     for (uint64 i = 0; i < SPI_processed; i++)
// //     {
// //         HeapTuple tuple = SPI_tuptable->vals[i];
// //         // Extract necessary fields from tuple
// //         bool isNull;
// //         int32 block_num = DatumGetInt32(SPI_getbinval(tuple, SPI_tuptable->tupdesc, 1, &isNull)); // Assuming num is at column 1
// //         block_num = block_num;
        
// //         // Call your processing functions here...
// //         // replay_block() equivalent processing on this tuple
// //         //block_bin_t result = block_to_bin(tuple); // Make sure to adapt block_to_bin to work with HeapTuple
// //         // ... additional processing
// //     }

  


// //     result res(SPI_tuptable, SPI_tuptable->tupdesc, SPI_processed);
// //     SPI_finish();
// //     return res;
// // }

// }  // namespace spixx
