#include "operation_base.hpp"

#include <hive/protocol/forward_impacted.hpp>
#include <hive/protocol/misc_utilities.hpp>

#include <fc/io/json.hpp>
#include <fc/string.hpp>

#include <vector>



#include "postgres.h"
#include "fmgr.h"

PG_FUNCTION_INFO_V1(consensus_state_provider_replay);

Datum consensus_state_provider_replay(PG_FUNCTION_ARGS);



int main()
{
    consensus_state_provider_replay();
    return 0;
}
