#include "psql_utils/postgres_includes.hpp"

#include "include/asset_unique_id.hpp"

#include "psql_utils/pg_cxx.hpp"

#include <hive/protocol/asset_symbol.hpp>

#include <algorithm>
#include <string>

extern "C" void issue_error_with_code(int sql_errcode, const char* msg);

namespace {

// Helper function to convert string to unsigned __int128
unsigned __int128 string_to_u128(const char* str) {
    if (*str < '0' || *str > '9')
    {
        ereport(ERROR, (errcode(ERRCODE_DATA_EXCEPTION),
            errmsg("string_to_u128: unexpected input '%s'", str)));
    }
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

// Helper for converting unsigned __int128 to string (std::to_string doesn't support __int128)
std::string u128_to_string(unsigned __int128 n) {
    if (n == 0) return "0";
    char buffer[40]; // 128 bits = max 39 decimal digits
    int i = 0;
    while (n > 0) {
        buffer[i++] = (n % 10) + '0';
        n /= 10;
    }
    std::string s(buffer, i);
    std::reverse(s.begin(), s.end());
    return s;
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

/**
  FUNCTION hafd.generate_asset_unique_id(
    IN _asset_symbol hafd.asset_symbol,
    IN _operation_id BIGINT,
    IN _subsequent_no BIGINT
  ) RETURNS hafd.asset_unique_id

  Generates a collision-free unique asset ID using 128-bit concatenation:
  - Bits 64-127: operation_id (64 bits)
  - Bits 32-63:  NAI extracted from asset_symbol (32 bits)
  - Bits 0-31:   subsequent_no (32 bits)

  Returns hafd.asset_unique_id to properly represent full 128-bit range.

  Raises exception if:
  - asset_symbol precision is not 0 (only precision 0 assets supported)
  - subsequent_no exceeds uint32_t max (4294967295)
  - operation_id is negative
*/
PG_FUNCTION_INFO_V1(generate_asset_unique_id);

Datum generate_asset_unique_id(PG_FUNCTION_ARGS)
{
    const uint32_t asset_num = PG_GETARG_INT64(0);
    const int64_t operation_id = PG_GETARG_INT64(1);
    const int64_t subsequent_no = PG_GETARG_INT64(2);

    if (operation_id < 0)
    {
        issue_error_with_code(ERRCODE_NUMERIC_VALUE_OUT_OF_RANGE,
            "operation_id must be non-negative");
    }

    // Validate subsequent_no is within uint32_t range
    if (subsequent_no < 0 || subsequent_no > static_cast<int64_t>(UINT32_MAX))
    {
        issue_error_with_code(ERRCODE_NUMERIC_VALUE_OUT_OF_RANGE,
            "subsequent_no must be between 0 and 4294967295 (uint32_t range)");
    }

    Datum retval = 0;

    PsqlTools::PsqlUtils::pg_call_cxx([asset_num, operation_id, subsequent_no, &retval]() {
        // Decode asset_symbol to get NAI and validate precision
        hive::protocol::asset_symbol_type ast = hive::protocol::asset_symbol_type::from_asset_num(asset_num);

        // Only precision 0 assets are supported
        if (ast.decimals() != 0)
        {
            issue_error_with_code(ERRCODE_INVALID_PARAMETER_VALUE,
                "generate_asset_unique_id only supports precision 0 assets");
        }

        uint32_t nai = ast.to_nai();

        // Build 128-bit ID with bit concatenation (no addition = no collision risk)
        // Layout: [operation_id (64 bits)][NAI (32 bits)][subsequent_no (32 bits)]
        unsigned __int128 full_id = 0;
        full_id = static_cast<unsigned __int128>(static_cast<uint64_t>(operation_id));
        full_id <<= 64;
        full_id |= (static_cast<unsigned __int128>(nai) << 32);
        full_id |= static_cast<unsigned __int128>(subsequent_no);

        // Convert to NUMERIC via string (PostgreSQL NUMERIC handles arbitrary precision)
        std::string id_str = u128_to_string(full_id);
        retval = PsqlTools::PsqlUtils::cxx_direct_call_pg(
            numeric_in,
            CStringGetDatum(id_str.c_str()),
            ObjectIdGetDatum(InvalidOid),
            Int32GetDatum(-1)
        );
    }, ERRCODE_DATA_EXCEPTION);

    PG_RETURN_DATUM(retval);
}

} // extern "C"
