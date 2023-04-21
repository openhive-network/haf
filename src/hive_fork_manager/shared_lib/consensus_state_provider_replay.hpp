#pragma once

namespace hive { namespace app {
void consensus_state_provider_replay_impl(int from, int to, const char *context, const char *postgres_url, const char* shared_memory_bin_path);
}}
