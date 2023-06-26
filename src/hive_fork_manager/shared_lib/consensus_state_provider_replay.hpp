#pragma once

#include <string>
#include <vector>

namespace fc 
{
  class variant;
}

#include <hive/chain/full_block.hpp>

namespace hive{ namespace chain{
  class database;
}}

namespace consensus_state_provider {
bool consensus_state_provider_replay_impl(int from,
                                          int to,
                                          const char* context,
                                          const char* shared_memory_bin_path,
                                          const char* postgres_url);

struct csp_sesion_type
{
  std::string context, shared_memory_bin_path, postgres_url;
  hive::chain::database* db;
};

csp_sesion_type* csp_init_impl(const char* context,
                               const char* shared_memory_bin_path,
                               const char* postgres_url);

int initialize_context(const char* context, const char* shared_memory_bin_path, const char*  postgres_url);
void consensus_state_provider_finish_impl(const char* context, const char* shared_memory_bin_path);
int consensus_state_provider_get_expected_block_num_impl(const char* context,
                                                         const char* shared_memory_bin_path, const char* postgres_url);
int session_consensus_state_provider_get_expected_block_num_impl(consensus_state_provider::csp_sesion_type* csp_session);
                                                         

}  // namespace consensus_state_provider
