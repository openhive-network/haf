#pragma once

#include <string>
#include <vector>
#include <fc/variant.hpp>

namespace consensus_state_provider
{
  void consensus_state_provider_replay_impl(int from, int to, const char *context, const char *postgres_url, const char* shared_memory_bin_path);
  

  int consume_variant_block_impl(const fc::variant& v, const char* context, int block_num, const char* shared_memory_bin_path);

  void consensus_state_provider_finish_impl(const char* context, const char* shared_memory_bin_path);
  int consensus_state_provider_get_expected_block_num_impl(const char* context, const char* shared_memory_bin_path);


}
