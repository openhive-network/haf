//#include <psql_utils/postgres_includes.hpp>
//#include "/home/haf_admin/playground/haf/src/psql_utils/include/psql_utils/postgres_includes.hpp"
#include <hive/protocol/operations.hpp>
#include <psql_utils/postgres_includes.hpp>

    #include "postgres.h"

#include "meat.hpp"

extern "C" {
    #include "fmgr.h"
    // #include "utils/bool.h"

    PG_MODULE_MAGIC;

    PG_FUNCTION_INFO_V1(run_consensus_replay_pg);

    Datum
    run_consensus_replay_pg(PG_FUNCTION_ARGS)
    {
        char *context = text_to_cstring(PG_GETARG_TEXT_P(0));
        char *consensus_state_provider_storage = text_to_cstring(PG_GETARG_TEXT_P(1));
        char *postgres_url = text_to_cstring(PG_GETARG_TEXT_P(2));
        int from = PG_GETARG_INT32(3);
        int to = PG_GETARG_INT32(4);
        int step = PG_GETARG_INT32(5);

        bool result = run_consensus_replay(context, consensus_state_provider_storage, postgres_url, from, to, step);

        PG_RETURN_BOOL(result);
    }
}
