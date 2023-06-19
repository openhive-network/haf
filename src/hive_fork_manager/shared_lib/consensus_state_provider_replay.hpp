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
                                          const char* postgres_url,
                                          const char* shared_memory_bin_path);

int initialize_context(const char* context, const char* shared_memory_bin_path, const char*  postgres_url);
std::shared_ptr<hive::chain::full_block_type> from_variant_to_full_block_ptr(const fc::variant& v,
                                                                             int block_num);

void consensus_state_provider_finish_impl(const char* context, const char* shared_memory_bin_path);
int consensus_state_provider_get_expected_block_num_impl(const char* context,
                                                         const char* shared_memory_bin_path);

}  // namespace consensus_state_provider
