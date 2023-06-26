#pragma once

#include <string>
#include <vector>

namespace fc 
{
  class variant;
}

#include <hive/chain/full_block.hpp>


namespace consensus_state_provider {

struct csp_session_type;


bool consensus_state_provider_replay_impl(csp_session_type* csp_session,  int from, int to);                                          

csp_session_type* csp_init_impl(const char* context,
                               const char* shared_memory_bin_path,
                               const char* postgres_url);

void csp_finish_impl(csp_session_type*, bool wipe_clean_shared_memory_bin);
int consensus_state_provider_get_expected_block_num_impl(consensus_state_provider::csp_session_type* csp_session);
                                                         

}  // namespace consensus_state_provider
