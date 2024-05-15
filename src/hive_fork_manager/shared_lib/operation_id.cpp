#include "psql_utils/postgres_includes.hpp"

#include "include/operation_id.hpp"

#include "psql_utils/pg_cxx.hpp"

extern "C" {

PG_FUNCTION_INFO_V1( to_operation_id );
Datum to_operation_id(PG_FUNCTION_ARGS) {
    auto block_num = PG_GETARG_INT32(0);
    auto type_id = PG_GETARG_INT32(1);
    auto position_in_block = PG_GETARG_INT32(2);

    int64 result{0};
    auto get_id = [&result,&block_num,&type_id,&position_in_block ]() {
        result = to_operation_id(block_num, type_id, position_in_block);
    };
    PsqlTools::PsqlUtils::pg_call_cxx( get_id );

    PG_RETURN_INT64(result);
}

PG_FUNCTION_INFO_V1( operation_id_to_block_num );
Datum operation_id_to_block_num(PG_FUNCTION_ARGS) {
    auto id = PG_GETARG_INT64(0);

    int32 result{0};
    auto get_block_num = [&result,&id]() {
        result = operation_id_to_block_num(id);
    };
    PsqlTools::PsqlUtils::pg_call_cxx( get_block_num );

    PG_RETURN_INT32( result );
}

PG_FUNCTION_INFO_V1( operation_id_to_pos );
Datum operation_id_to_pos(PG_FUNCTION_ARGS) {
    auto id = PG_GETARG_INT64(0);

    int32 result{0};
    auto get_pos = [&result,&id]() {
        result = operation_id_to_pos(id);
    };
    PsqlTools::PsqlUtils::pg_call_cxx( get_pos );

    PG_RETURN_INT32( result );
}

PG_FUNCTION_INFO_V1( operation_id_to_type_id );
Datum operation_id_to_type_id(PG_FUNCTION_ARGS) {
    auto id = PG_GETARG_INT64(0);

    int32 result{0};
    auto get_type = [&result,&id]() {
        result = operation_id_to_type_id(id);
    };
    PsqlTools::PsqlUtils::pg_call_cxx( get_type );

    PG_RETURN_INT32( result );
}

} // extern "C"

