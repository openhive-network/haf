
#include "spixx.hpp"
#include "utils/builtins.h"  // For text_to_cstring

// namespace spixx {

// // field implementations
// field::field(Datum d, bool isN) : datum(d), isNull(isN) {}

// std::string field::asString() const {
//     if (isNull) return "NULL";
//     return text_to_cstring(DatumGetTextP(datum));
// }

// // row implementations
// row::row(HeapTuple t, TupleDesc td) : tuple(t), tupdesc(td) {}

// field row::operator[](const std::string& key) const {
//     int col = SPI_fnumber(tupdesc, key.c_str());
//     if (col <= 0) {
//         elog(ERROR, "Column not found");
//     }

//     Datum datum = SPI_getbinval(tuple, tupdesc, col, &isNull);
//     return field(datum, isNull);
// }

// // const_result_iterator implementations
// const_result_iterator::const_result_iterator(SPITupleTable *tt, int idx) : tuptable(tt), index(idx) {}

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

// // result implementations
// result::result() : tuptable(nullptr), proc(0) {}

// result::result(SPITupleTable *t, uint64 p) : tuptable(t), proc(p) {}

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

// // execute_query function
// result execute_query(const std::string& query) {
//     if (SPI_connect() != SPI_OK_CONNECT) {
//         elog(ERROR, "Failed connecting to SPI");
//     }

//     int ret = SPI_exec(query.c_str(), 0);
//     if (ret != SPI_OK_SELECT) {
//         SPI_finish();
//         elog(ERROR, "Failed executing query");
//     }

//     result res(SPI_tuptable, SPI_processed);

//     SPI_finish();
//     return res;
// }

// }  // namespace spixx

