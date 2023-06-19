#pragma once

#include <string>
#include <vector>

namespace fc 
{
  class variant;
}

#include <hive/chain/full_block.hpp>


namespace consensus_state_provider {
bool consensus_state_provider_replay_impl(int from,
                                          int to,
                                          const char* context,
                                          const char* shared_memory_bin_path,
                                          const char* postgres_url);

int initialize_context(const char* context, const char* shared_memory_bin_path, const char*  postgres_url);
void consensus_state_provider_finish_impl(const char* context, const char* shared_memory_bin_path);
int consensus_state_provider_get_expected_block_num_impl(const char* context,
                                                         const char* shared_memory_bin_path, const char* postgres_url);

}  // namespace consensus_state_provider
