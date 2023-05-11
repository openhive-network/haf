#include "operation_base.hpp"

#include <hive/protocol/forward_impacted.hpp>
#include <hive/protocol/misc_utilities.hpp>

#include <fc/io/json.hpp>
#include <fc/string.hpp>

#include <vector>





#include "consensus_state_provider_replay.hpp"



int main()
{
    auto ok = consensus_state_provider::consensus_state_provider_replay_impl(
        1,
        1000,
        "driverc",
        "postgresql:///haf_block_log",
        "/home/hived/datadir/consensus_state_provider");
    return ok != 0;
}
