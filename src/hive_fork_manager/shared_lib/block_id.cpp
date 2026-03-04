#include "psql_utils/postgres_includes.hpp"

#include "include/block_id.hpp"

#include "psql_utils/pg_cxx.hpp"

extern "C" {

PG_FUNCTION_INFO_V1( make_block_id );
Datum make_block_id(PG_FUNCTION_ARGS) {
    auto block_num = PG_GETARG_INT32(0);
    auto fork_id = PG_GETARG_INT64(1);

    int64 result{0};
    auto get_id = [&result, &block_num, &fork_id]() {
        result = make_haf_block_id(block_num, fork_id);
    };
    PsqlTools::PsqlUtils::pg_call_cxx( get_id );

    PG_RETURN_INT64(result);
}

PG_FUNCTION_INFO_V1( block_id_to_num );
Datum block_id_to_num(PG_FUNCTION_ARGS) {
    auto id = PG_GETARG_INT64(0);

    int32 result{0};
    auto get_num = [&result, &id]() {
        result = haf_block_id_to_num(id);
    };
    PsqlTools::PsqlUtils::pg_call_cxx( get_num );

    PG_RETURN_INT32( result );
}

PG_FUNCTION_INFO_V1( block_id_to_fork );
Datum block_id_to_fork(PG_FUNCTION_ARGS) {
    auto id = PG_GETARG_INT64(0);

    int64 result{0};
    auto get_fork = [&result, &id]() {
        result = haf_block_id_to_fork(id);
    };
    PsqlTools::PsqlUtils::pg_call_cxx( get_fork );

    PG_RETURN_INT64( result );
}

} // extern "C"

// bench: force full build
