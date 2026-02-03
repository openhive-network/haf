#include "psql_utils/postgres_includes.hpp"

#include "include/asset_unique_id.hpp"

#include "psql_utils/pg_cxx.hpp"

#include <hive/protocol/asset_symbol.hpp>

namespace {

// Helper function to convert string to unsigned __int128
unsigned __int128 string_to_u128(const char* str) {
    unsigned __int128 result = 0;
    while (*str >= '0' && *str <= '9') {
        result = result * 10 + (*str - '0');
        ++str;
    }
    return result;
}

// Helper to convert NUMERIC Datum to unsigned __int128
unsigned __int128 numeric_to_u128(Datum num) {
    const char* str = DatumGetCString(
        PsqlTools::PsqlUtils::cxx_direct_call_pg(numeric_out, num)
    );
    return string_to_u128(str);
}

} // anonymous namespace

extern "C" {

PG_FUNCTION_INFO_V1(asset_unique_id_to_operation_id);
Datum asset_unique_id_to_operation_id(PG_FUNCTION_ARGS) {
    Datum numeric_datum = PG_GETARG_DATUM(0);

    int64 result = 0;
    auto extract = [&numeric_datum, &result]() {
        unsigned __int128 id = numeric_to_u128(numeric_datum);
        result = asset_unique_id_to_operation_id(id);
    };
    PsqlTools::PsqlUtils::pg_call_cxx(extract);

    PG_RETURN_INT64(result);
}

PG_FUNCTION_INFO_V1(asset_unique_id_to_asset_symbol);
Datum asset_unique_id_to_asset_symbol(PG_FUNCTION_ARGS) {
    Datum numeric_datum = PG_GETARG_DATUM(0);

    int64 result = 0;
    auto extract = [&numeric_datum, &result]() {
        unsigned __int128 id = numeric_to_u128(numeric_datum);
        uint32_t nai = asset_unique_id_to_nai(id);

        // Reconstruct asset_symbol from NAI with precision 0
        hive::protocol::asset_symbol_type ast =
            hive::protocol::asset_symbol_type::from_nai(nai, 0);
        result = ast.asset_num;
    };
    PsqlTools::PsqlUtils::pg_call_cxx(extract);

    PG_RETURN_INT64(result);
}

PG_FUNCTION_INFO_V1(asset_unique_id_to_subsequent_no);
Datum asset_unique_id_to_subsequent_no(PG_FUNCTION_ARGS) {
    Datum numeric_datum = PG_GETARG_DATUM(0);

    int64 result = 0;
    auto extract = [&numeric_datum, &result]() {
        unsigned __int128 id = numeric_to_u128(numeric_datum);
        result = asset_unique_id_to_subsequent_no(id);
    };
    PsqlTools::PsqlUtils::pg_call_cxx(extract);

    PG_RETURN_INT64(result);
}

} // extern "C"
